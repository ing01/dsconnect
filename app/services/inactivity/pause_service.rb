# Fluxo de PAUSA por inatividade (ver Inactivity::PauseConfig).
#
# Pausar = usar o status `snoozed` ("Pausada" na interface), SEM `snoozed_until`
# (o job que reabre adiadas so olha as que tem data, entao esta nunca reabre
# sozinha). O estado fica em `additional_attributes`:
#   paused_at, pause_deadline (prazo final, ISO8601), paused_assignee_id,
#   pause_origin ('inbox' | 'queue'), pause_close_tickets, pause_extensions
#   (auditoria das extensoes) e pause_count (quantas vezes ja foi pausada).
#
# - pause!    : libera o atendente, avisa o cliente e conta o prazo.
# - resume!   : o cliente voltou no prazo (qualquer mensagem) -> reabre; vincula ao
#               atendente anterior se estiver online e disponivel, senao volta pra fila.
# - decline!  : o cliente respondeu NAO -> encerra.
# - finalize! : o prazo acabou sem resposta -> encerra (fluxo de inatividade).
# - extend!   : o analista soma tempo ao prazo final, com motivo obrigatorio.
class Inactivity::PauseService
  class Error < StandardError; end

  NOTICE_KEY = Queues::InactivityService::NOTICE_KEY
  PAUSE_KEYS = %w[paused_at pause_deadline paused_assignee_id pause_origin pause_close_tickets pause_extensions].freeze
  DECLINE_WORDS = %w[nao n no encerrar].freeze
  AFFIRMATIVE_WORDS = %w[sim s yes y ok claro quero].freeze
  # O titulo do botao e' o que volta como texto da resposta ("Sim"/"Não"), que
  # `affirmative_reply?`/`decline_reply?` ja reconhecem.
  YES_NO_ITEMS = [{ 'title' => 'Sim', 'value' => 'sim' }, { 'title' => 'Não', 'value' => 'nao' }].freeze

  attr_reader :conversation, :config

  def initialize(conversation:, config:, origin: 'inbox', close_tickets: false)
    @conversation = conversation
    @config = config
    @origin = origin
    @close_tickets = close_tickets
  end

  class << self
    def paused?(conversation)
      conversation.snoozed? && conversation.additional_attributes&.dig('paused_at').present?
    end

    # Servico de uma conversa que JA esta pausada, com a configuracao da origem
    # da pausa (Fila ou caixa de entrada).
    def for_paused(conversation)
      return unless paused?(conversation)

      if conversation.additional_attributes['pause_origin'] == 'queue' && conversation.queue.present?
        new(conversation: conversation, config: conversation.queue.pause_config, origin: 'queue', close_tickets: true)
      else
        new(conversation: conversation, config: conversation.inbox.pause_config, origin: 'inbox',
            close_tickets: conversation.additional_attributes['pause_close_tickets'] == true)
      end
    end

    # Chamado por Message#reopen_conversation. Retorna true quando a mensagem do
    # cliente foi tratada aqui (a reabertura padrao nao deve acontecer).
    #
    # Qualquer mensagem do cliente retoma a conversa - para o atendente anterior, se
    # estiver disponivel, ou para a fila. So' o "nao" (que a propria mensagem de pausa
    # oferece) encerra. Antes, com a retomada "com um clique" desligada, um texto que
    # nao fosse "sim"/"nao" deixava a conversa pausada: a mensagem real do cliente
    # ficava escondida em Pausadas, sem ninguem ver.
    def handle_incoming(message)
      service = for_paused(message.conversation)
      return false if service.nil?

      return service.finalize_expired_before_reply! if service.expired?
      return service.decline! if service.decline_reply?(message)

      service.resume!
    end
  end

  def allowed?
    config.enabled? && pause_count < config.max_pauses && conversation.can_reply?
  end

  def expired?
    deadline = pause_deadline
    deadline.present? && deadline <= Time.current
  end

  def pause!
    deadline = business_time.add_minutes(Time.current, config.pause_window)
    paused = false
    # Conversa travada e recarregada: se outra rodada ja pausou ou encerrou
    # enquanto esperavamos, nao pausa (nem avisa) de novo.
    conversation.with_lock do
      next unless conversation.open?

      conversation.update!(
        status: :snoozed, assignee_id: nil,
        additional_attributes: attrs.merge(
          'paused_at' => Time.current.iso8601, 'pause_deadline' => deadline.iso8601,
          'paused_assignee_id' => conversation.assignee_id, 'pause_origin' => @origin,
          'pause_close_tickets' => @close_tickets, 'pause_count' => pause_count + 1
        )
      )
      clear_requeued_flag
      paused = true
    end
    send_notice('pause', 'pause', { 'data_hora_limite' => format_time(deadline) }, yes_no_buttons: true) if paused
  end

  # Prazos so no horario de atendimento da caixa (se a configuracao e a caixa
  # pedirem); usado pelos servicos de inatividade pra contar aviso e pausa.
  def business_time
    @business_time ||= Inactivity::BusinessTime.new(conversation.inbox, enabled: config.enabled? && config.respect_working_hours?)
  end

  def resume!
    previous = previous_agent
    ActiveRecord::Base.transaction do
      conversation.update!(status: :open, snoozed_until: nil, assignee_id: previous&.id, additional_attributes: attrs.except(*PAUSE_KEYS))
      clear_requeued_flag if previous.nil?
      reopen_tickets
    end
    notify_resumed(previous)
    ::Queues::AutoAssignJob.perform_later(conversation) if previous.nil? && conversation.queue_id.present?
    true
  end

  # A equipe retomou a conversa pausada ANTES do prazo (botao Reabrir/Pausadas):
  # quem clicou assume, o cliente e' avisado e os tickets fechados por
  # inatividade reabrem - o mesmo que a volta do cliente faz, sem esperar por ele.
  def resume_manually!(user)
    ActiveRecord::Base.transaction do
      conversation.update!(status: :open, snoozed_until: nil, assignee_id: user.id, additional_attributes: attrs.except(*PAUSE_KEYS))
      reopen_tickets
    end
    send_notice('resume_same_agent', 'resume', { 'atendente' => user.available_name })
    true
  end

  def decline!
    send_notice('decline', 'decline')
    resolve!
    true
  end

  def finalize!
    send_notice('finalize', 'close')
    resolve!
    true
  end

  def decline_reply?(message)
    DECLINE_WORDS.include?(normalize(message.content))
  end

  def affirmative_reply?(message)
    AFFIRMATIVE_WORDS.include?(normalize(message.content))
  end

  # O prazo venceu antes do job rodar e o cliente escreveu: encerra e deixa a
  # reabertura padrao (conversa resolvida) tratar a mensagem como contato novo.
  def finalize_expired_before_reply!
    finalize!
    false
  end

  def extend!(minutes:, reason:, user:, notify: true)
    validate_extension!(minutes, reason)
    previous_deadline = pause_deadline
    new_deadline = business_time.add_minutes(previous_deadline, minutes.to_i)
    entry = { 'user_id' => user&.id, 'user_name' => user&.name, 'at' => Time.current.iso8601, 'minutes' => minutes.to_i,
              'reason' => reason.to_s.strip, 'previous_deadline' => previous_deadline.iso8601, 'new_deadline' => new_deadline.iso8601 }
    conversation.update!(additional_attributes: attrs.merge('pause_deadline' => new_deadline.iso8601,
                                                            'pause_extensions' => extensions + [entry]))
    create_activity("#{user&.name} estendeu a pausa em #{minutes.to_i} min até #{format_time(new_deadline)}. Motivo: #{entry['reason']}")
    notify_extension(entry, new_deadline) if notify
    entry
  end

  def close_tickets!
    conversation.tickets.where(status: [:open, :resolved]).find_each do |ticket|
      ticket.close!(nil, skip_requirements: true)
      ticket.as_administrative_change { ticket.update!(close_reason: 'inactivity') }
    end
  end

  private

  def attrs
    conversation.additional_attributes || {}
  end

  def pause_count
    attrs['pause_count'].to_i
  end

  def extensions
    attrs['pause_extensions'] || []
  end

  def pause_deadline
    value = attrs['pause_deadline']
    Time.zone.parse(value) if value.present?
  end

  def validate_extension!(minutes, reason)
    raise Error, 'not_paused' unless self.class.paused?(conversation)
    raise Error, 'extension_disabled' unless config.extension_enabled?
    raise Error, 'reason_required' if reason.to_s.strip.blank?
    raise Error, 'invalid_minutes' unless minutes.to_i.positive?
    raise Error, 'duration_exceeded' if config.max_extension_minutes && minutes.to_i > config.max_extension_minutes
    raise Error, 'limit_reached' if config.max_extensions && extensions.size >= config.max_extensions
  end

  # Encerra a conversa pelo fluxo de inatividade (CSAT sai pelo evento de
  # conversa resolvida). A contagem de pausas zera: um novo contato e uma nova sessao.
  def resolve!
    ActiveRecord::Base.transaction do
      conversation.inactivity_resolved_after = paused_minutes
      conversation.update!(status: :resolved, additional_attributes: attrs.except(*PAUSE_KEYS, 'pause_count'))
      close_tickets! if @close_tickets
    end
  end

  def paused_minutes
    paused_at = attrs['paused_at']
    paused_at ? ((Time.current - Time.zone.parse(paused_at)) / 60).round : 0
  end

  # Atendente anterior so volta se a configuracao deixa, ele esta online e
  # disponivel e ainda atende esta caixa de entrada.
  def previous_agent
    return unless config.keep_previous_agent?

    id = attrs['paused_assignee_id']
    return if id.blank?

    account_user = conversation.account.account_users.find_by(user_id: id)
    return unless account_user&.availability_status == 'online'
    # Mesma regra da distribuicao automatica: quem esta no bloqueio de almoco
    # (de 20 min antes ate o fim do almoco) nao recebe conversa nova.
    return if account_user.lunch_blackout_now?
    # Mesma Excecao da distribuicao (agentes fora do rodizio, configurada em
    # Colaboradores/Automacao) que o rodizio normal ja respeita - sem isso, o
    # atendente anterior continuava recebendo a conversa de volta so' por ter
    # sido quem atendia antes da pausa, mesmo estando marcado pra ficar fora da
    # distribuicao automatica. Bug URGENTE relatado pela Ingrid, 2026-11-11 -
    # retornar nil aqui devolve a conversa pra fila (se houver) ou deixa
    # AutoAssignmentHandler escolher um agente de verdade pelo rodizio.
    return if excluded_from_distribution?(id)

    user = account_user.user
    user if conversation.inbox.assignable_agents.include?(user)
  end

  def excluded_from_distribution?(agent_id)
    inbox = conversation.inbox
    excluded_ids =
      if inbox.whatsapp?
        conversation.account.whatsapp_auto_assignment_excluded_agent_ids
      elsif inbox.client_portal?
        conversation.account.client_portal_auto_assignment_excluded_agent_ids
      end
    Array(excluded_ids).map(&:to_i).include?(agent_id.to_i)
  end

  def reopen_tickets
    conversation.tickets.where(status: :closed, close_reason: 'inactivity').find_each do |ticket|
      ticket.reopen!(nil)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    end
  end

  def notify_resumed(previous)
    if previous
      send_notice('resume_same_agent', 'resume', { 'atendente' => previous.available_name })
    else
      send_notice('resume_queue', 'resume')
    end
    send_out_of_hours_notice
  end

  def send_out_of_hours_notice
    inbox = conversation.inbox
    return unless inbox.out_of_office?

    text = [config.message('resume_out_of_hours'), inbox.out_of_office_message.presence].compact.join("\n\n")
    create_notice(text, 'resume')
  end

  def notify_extension(entry, new_deadline)
    reason = entry['reason'].present? ? "\n\nMotivo: #{entry['reason']}" : ''
    send_notice('extension', 'extension', { 'motivo' => reason, 'data_hora_limite' => format_time(new_deadline) })
  end

  def send_notice(key, kind, vars = {}, yes_no_buttons: false)
    content = config.message(key).dup
    vars.each { |name, value| content.gsub!("{#{name}}", value.to_s) }
    content.gsub!(/\{\w+\}/, '') # variavel sem valor nao pode vazar pro cliente
    create_notice(content, kind, yes_no_buttons: yes_no_buttons)
  end

  def create_notice(content, kind, yes_no_buttons: false)
    return if content.blank? || !conversation.can_reply?

    attributes = { NOTICE_KEY => kind }
    message_attributes = {}
    if yes_no_buttons && buttons_supported?
      message_attributes[:content_type] = :input_select
      attributes['items'] = YES_NO_ITEMS
    end
    conversation.messages.create!(
      account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
      content: content, content_attributes: attributes, **message_attributes
    )
  end

  # Botoes Sim/Nao so onde o canal entrega botao interativo: WhatsApp Cloud API
  # e 360dialog. AstereZap (sessao nao oficial), Twilio e o Portal mandam o texto
  # "responda SIM ou NAO"; a resposta digitada continua valendo.
  def buttons_supported?
    channel = conversation.inbox.channel
    channel.is_a?(Channel::Whatsapp) && %w[default whatsapp_cloud].include?(channel.provider)
  end

  def create_activity(content)
    conversation.messages.create!(
      account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content
    )
  end

  # A pausa nao e' "devolver pra fila": nao deve marcar a conversa como devolvida.
  def clear_requeued_flag
    conversation.update_column(:requeued_at, nil) # rubocop:disable Rails/SkipsModelValidations
  end

  def format_time(time)
    time.in_time_zone.strftime('%d/%m/%Y às %H:%M')
  end

  def normalize(text)
    I18n.transliterate(text.to_s.strip.downcase).gsub(/[^a-z\s]/, '').strip
  end
end
