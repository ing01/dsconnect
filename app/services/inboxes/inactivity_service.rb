# Aviso e encerramento por inatividade do cliente, configurados por caixa de
# entrada (`inactivity_config`, Portal do Cliente e WhatsApp). So' atua quando a
# ULTIMA mensagem da conversa foi da equipe - estamos esperando o cliente. As
# mensagens deste servico levam `inactivity_notice` e nao contam como mensagem
# da equipe, senao reiniciariam o relogio.
#
# Fluxo: passou `nudge_after` minutos da ultima mensagem da equipe -> envia o
# aviso (`inactivity_message`) e grava o momento; passou `close_after` minutos
# desde o aviso (ou desde a mensagem da equipe, se nao ha aviso configurado) e o
# cliente continua calado -> envia a mensagem de encerramento (`resolve_message`)
# e resolve. A avaliacao (CSAT) sai sozinha pelo evento de conversa resolvida,
# se estiver ativada na caixa. Se o cliente responder, tudo recomeca.
class Inboxes::InactivityService
  NOTICE_KEY = Queues::InactivityService::NOTICE_KEY
  NUDGED_AT_KEY = Queues::InactivityService::NUDGED_AT_KEY

  pattr_initialize [:inbox!]

  def perform
    nudge_after = inbox.inactivity_minutes('nudge_after')
    close_after = inbox.inactivity_minutes('close_after')
    pause_after = inbox.pause_config.enabled? ? inbox.pause_config.pause_after : nil
    threshold = [nudge_after, close_after, pause_after].compact.min
    return if threshold.blank?

    inbox.conversations.open.includes(:queue).where('last_activity_at <= ?', threshold.minutes.ago).find_each do |conversation|
      next if handled_by_queue?(conversation)

      process(conversation, nudge_after, close_after)
    rescue StandardError => e
      # Uma conversa com problema nao pode travar as outras; e' tentada de novo na proxima rodada.
      ChatwootExceptionTracker.new(e, account: inbox.account).capture_exception
    end
  end

  private

  # No Portal, quando a Fila da conversa tem regras de inatividade (aviso,
  # encerramento ou pausa), quem cuida dela e' Queues::InactivityService. Os dois
  # servicos rodam em paralelo (jobs separados) e, se ambos agissem, o cliente
  # recebia o aviso em duplicidade e com o texto de uma ou de outra configuracao.
  def handled_by_queue?(conversation)
    queue = conversation.queue
    inbox.client_portal? && queue.present? && queue.active? && queue.inactivity_rules?
  end

  def process(conversation, nudge_after, close_after)
    last_message = last_chat_message(conversation)
    return unless last_message&.outgoing?

    pause = pause_service(conversation)
    final_delay = pause ? pause.config.pause_after : close_after
    nudged_at = nudged_at_for(conversation, last_message)
    if nudged_at
      finish(conversation, pause, nudged_at) if final_delay && elapsed?(nudged_at, final_delay)
    elsif nudge_after
      nudge(conversation) if elapsed?(last_message.created_at, nudge_after)
    elsif final_delay && elapsed?(last_message.created_at, final_delay)
      finish(conversation, pause, last_message.created_at)
    end
  end

  # Pausa (se o fluxo esta ligado e ainda ha pausa disponivel pra esta
  # conversa) ou encerra direto, como sempre foi.
  def pause_service(conversation)
    service = Inactivity::PauseService.new(conversation: conversation, config: inbox.pause_config, origin: 'inbox')
    service if service.allowed?
  end

  def finish(conversation, pause, since)
    pause ? pause.pause! : close(conversation, since)
  end

  def last_chat_message(conversation)
    conversation.messages
                .where(message_type: [:incoming, :outgoing], private: false)
                .where("COALESCE(content_attributes ->> '#{NOTICE_KEY}', '') = ''")
                .order(:created_at, :id).last
  end

  # O aviso so vale se for posterior a ultima mensagem da equipe.
  def nudged_at_for(conversation, last_message)
    value = conversation.additional_attributes&.dig(NUDGED_AT_KEY)
    nudged_at = value && Time.zone.parse(value)
    nudged_at = nil unless nudged_at && nudged_at > last_message.created_at
    nudged_at || nudge_notice_time(conversation, last_message)
  end

  # Fonte da verdade do aviso ja enviado: o marcador em `additional_attributes`
  # e, se ele nao foi gravado, a PROPRIA mensagem de aviso. O marcador e' gravado
  # DEPOIS de criar a mensagem; se algo falhar nesse intervalo (ex.: um listener
  # levantando erro no commit da mensagem), a mensagem ja saiu mas o marcador
  # nao existe - e a proxima rodada mandava o aviso de novo, a cada ciclo, e
  # nunca chegava ao encerramento.
  def nudge_notice_time(conversation, last_message)
    conversation.messages
                .where('created_at > ?', last_message.created_at)
                .where("content_attributes ->> '#{NOTICE_KEY}' = 'nudge'")
                .minimum(:created_at)
  end

  # Com a pausa ligada, os prazos so correm no horario de atendimento da caixa
  # (se a configuracao pedir e a caixa tiver horario ligado).
  def elapsed?(since, minutes)
    config = inbox.pause_config
    Inactivity::BusinessTime.new(inbox, enabled: config.enabled? && config.respect_working_hours?).elapsed?(since, minutes)
  end

  # O aviso e o marcador saem na mesma transacao, com a conversa TRAVADA e
  # recarregada: se outra rodada (ou outro job) avisou enquanto esperavamos, o
  # estado novo ja mostra o aviso e nao mandamos de novo.
  def nudge(conversation)
    conversation.with_lock do
      last_message = last_chat_message(conversation)
      next unless conversation.open? && last_message&.outgoing? && nudged_at_for(conversation, last_message).nil?

      send_notice(conversation, inbox.inactivity_config['inactivity_message'], 'nudge')
      conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(NUDGED_AT_KEY => Time.current.iso8601))
    end
  end

  def close(conversation, since)
    conversation.with_lock do
      next unless conversation.open? && last_chat_message(conversation)&.outgoing?

      send_notice(conversation, inbox.inactivity_config['resolve_message'], 'close')
      conversation.inactivity_resolved_after = ((Time.current - since) / 60).round
      conversation.update!(status: :resolved)
    end
  end

  def send_notice(conversation, content, kind)
    return if content.blank? || !conversation.can_reply?

    conversation.messages.create!(
      account_id: conversation.account_id, inbox_id: inbox.id, message_type: :outgoing,
      content: content, content_attributes: { NOTICE_KEY => kind }
    )
  end
end
