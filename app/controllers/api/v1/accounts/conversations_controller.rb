class Api::V1::Accounts::ConversationsController < Api::V1::Accounts::BaseController
  include Events::Types
  include DateRangeHelper
  include HmacConcern
  include ConversationCustomAttributesConcern

  before_action :conversation, except: [:index, :meta, :search, :create, :filter]
  before_action :inbox, :contact, :contact_inbox, only: [:create]
  before_action :ensure_contact_not_in_attendance, only: [:create]
  before_action :find_waiting_conversation, only: [:create]
  before_action :ensure_contact_not_paused, only: [:create]

  ATTACHMENT_RESULTS_PER_PAGE = 100

  def index
    result = conversation_finder.perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  end

  def meta
    result = conversation_finder.perform_meta_only
    @conversations_count = result[:count]
  end

  def search
    result = conversation_finder.perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  end

  # Tickets em andamento ligados a conversa, para o dialogo de "Cancelar conversa"
  # mostrar o que sera cancelado junto. `other_conversations_count` > 0 quer dizer
  # que o ticket tem OUTRAS conversas: ai quem cancela escolhe se ele tambem vai.
  def linked_tickets
    tickets = cancellable_tickets
    others = other_conversations_counts(tickets)
    render json: {
      payload: tickets.map do |ticket|
        { id: ticket.id, display_id: ticket.display_id, title: ticket.title, status: ticket.status,
          other_conversations_count: others.fetch(ticket.id, 0) }
      end
    }
  end

  def attachments
    @attachments_count = @conversation.attachments.count
    @attachments = @conversation.attachments
                                .includes({ file_attachment: :blob }, message: [:inbox, { sender: { avatar_attachment: :blob } }])
                                .order(created_at: :desc)
                                .page(attachment_params[:page])
                                .per(ATTACHMENT_RESULTS_PER_PAGE)
  end

  def show; end

  def create
    # Antes de criar qualquer coisa: o ticket tem de existir NA CONTA e quem chama tem de
    # poder altera-lo - senao a conversa nasceria e o vinculo seria recusado depois.
    ticket = ticket_to_link
    ActiveRecord::Base.transaction do
      @conversation = pull_or_build_conversation
      mark_as_agent_initiated(@conversation) unless @pulled_from_queue
      Messages::MessageBuilder.new(Current.user, @conversation, params[:message]).perform if params[:message].present?
      # Na mesma transacao: ou a conversa nasce vinculada, ou nao nasce. Vale tambem quando
      # o cliente ja estava na fila e a conversa dele foi assumida (`@pulled_from_queue`) -
      # e' a conversa que ficou, e e' ela que o ticket passa a mostrar.
      ticket&.ticket_conversations&.find_or_create_by!(conversation: @conversation)
    end
  end

  def update
    @conversation.update!(permitted_update_params)
  end

  def filter
    result = ::Conversations::FilterService.new(params.permit!, current_user, current_account).perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def mute
    @conversation.mute!
    head :ok
  end

  def unmute
    @conversation.unmute!
    head :ok
  end

  # Estende o prazo de uma pausa por inatividade: soma `hours`/`minutes` ao
  # prazo final atual, com `reason` obrigatorio (fica na auditoria da conversa).
  def extend_pause
    service = Inactivity::PauseService.for_paused(@conversation)
    return render json: { error: 'not_paused' }, status: :unprocessable_entity if service.nil?

    entry = service.extend!(
      minutes: (params[:hours].to_i * 60) + params[:minutes].to_i, reason: params[:reason], user: Current.user,
      notify: ActiveModel::Type::Boolean.new.cast(params.fetch(:notify_customer, true))
    )
    render json: entry
  rescue Inactivity::PauseService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def transcript
    render json: { error: 'email param missing' }, status: :unprocessable_entity and return if params[:email].blank?
    return render_payment_required('Email transcript is not available on your plan') unless @conversation.account.email_transcript_enabled?
    return head :too_many_requests unless @conversation.account.within_email_rate_limit?

    ConversationReplyMailer.with(account: @conversation.account).conversation_transcript(@conversation, params[:email])&.deliver_later
    @conversation.account.increment_email_sent_count
    head :ok
  end

  def toggle_status
    return render_cancel_reason_required if cancelling? && cancel_reason.blank?

    # FIXME: move this logic into a service object
    if cancelling?
      @status = cancel_with_linked_tickets
    elsif bot_handoff?
      @conversation.bot_handoff!
    elsif resuming_inactivity_pause?
      @status = Inactivity::PauseService.for_paused(@conversation).resume_manually!(Current.user)
    elsif params[:status].present?
      set_conversation_status
      @status = @conversation.save!
    else
      @status = @conversation.toggle_status
    end
    handle_human_open if @conversation.open? && Current.user.is_a?(User)
  end

  # Reabrir uma conversa pausada por inatividade pela interface = retomar o
  # atendimento (assume quem clicou e avisa o cliente), nao so' mudar o status.
  def resuming_inactivity_pause?
    params[:status] == 'open' && Current.user.is_a?(User) && Inactivity::PauseService.paused?(@conversation)
  end

  def bot_handoff?
    return false unless Current.user.is_a?(AgentBot)

    @conversation.status == 'pending' && params[:status] == 'open'
  end

  def toggle_priority
    @conversation.toggle_priority(params[:priority])
    head :ok
  end

  def toggle_typing_status
    typing_status_manager = ::Conversations::TypingStatusManager.new(@conversation, Current.user, params)
    typing_status_manager.toggle_typing_status
    head :ok
  end

  def update_last_seen
    # High-traffic accounts generate excessive DB writes when agents frequently switch between conversations.
    # Throttle last_seen updates to once per hour when there are no unread messages to reduce DB load.
    # Always update immediately if there are unread messages to maintain accurate read/unread state.
    # Visiting a conversation should clear any unread inbox notifications for this conversation.
    Notification::MarkConversationReadService.new(user: Current.user, account: Current.account, conversation: @conversation).perform
    return update_last_seen_on_conversation(DateTime.now.utc, true) if assignee? && @conversation.assignee_unread_messages.any?
    return update_last_seen_on_conversation(DateTime.now.utc, false) if !assignee? && @conversation.unread_messages.any?

    # No unread messages - apply throttling to limit DB writes
    return unless should_update_last_seen?

    update_last_seen_on_conversation(DateTime.now.utc, assignee?)
  end

  def unread
    last_incoming_message = @conversation.messages.incoming.last
    last_seen_at = last_incoming_message.created_at - 1.second if last_incoming_message.present?
    update_last_seen_on_conversation(last_seen_at, true)
  end

  def destroy
    authorize @conversation, :destroy?
    ::Conversations::DeleteService.new(conversation: @conversation, user: Current.user, ip: request.ip).perform
    head :ok
  end

  private

  def permitted_update_params
    # TODO: Move the other conversation attributes to this method and remove specific endpoints for each attribute
    params.permit(:priority)
  end

  def attachment_params
    params.permit(:page)
  end

  def update_last_seen_on_conversation(last_seen_at, update_assignee)
    updates = { agent_last_seen_at: last_seen_at }
    updates[:assignee_last_seen_at] = last_seen_at if update_assignee.present?

    # rubocop:disable Rails/SkipsModelValidations
    @conversation.update_columns(updates)
    # rubocop:enable Rails/SkipsModelValidations

    ::Conversations::UnreadCounts::Notifier.new(@conversation).perform
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(Current.account).conversation_changed!
  end

  def should_update_last_seen?
    # Update if at least one relevant timestamp is older than 1 hour or not set
    # This prevents redundant DB writes when agents repeatedly view the same conversation
    agent_needs_update = @conversation.agent_last_seen_at.blank? || @conversation.agent_last_seen_at < 1.hour.ago
    return agent_needs_update unless assignee?

    # For assignees, check both timestamps - update if either is old
    assignee_needs_update = @conversation.assignee_last_seen_at.blank? || @conversation.assignee_last_seen_at < 1.hour.ago
    agent_needs_update || assignee_needs_update
  end

  def set_conversation_status
    @conversation.status = params[:status]
    mark_as_cancelled if cancelling?
    @conversation.snoozed_until = parse_date_time(params[:snoozed_until].to_s) if params[:snoozed_until]
  end

  def mark_as_cancelled
    @conversation.additional_attributes = (@conversation.additional_attributes || {}).merge(
      'cancelled' => true, 'cancelled_reason' => cancel_reason
    )
  end

  def cancelling?
    params[:status].to_s == 'resolved' && ActiveModel::Type::Boolean.new.cast(params[:cancelled])
  end

  def cancel_reason
    params[:cancel_reason].to_s.strip
  end

  def render_cancel_reason_required
    render json: { error: I18n.t('conversations.cancel.reason_required') }, status: :unprocessable_entity
  end

  # Cancelar a conversa cancela, junto e no mesmo passo, os tickets em andamento
  # ligados a ela - com o mesmo motivo. Se um deles falhar nada fica pela metade.
  # Ticket ja fechado ou cancelado nao e' tocado.
  def cancel_with_linked_tickets
    Conversation.transaction do
      set_conversation_status
      saved = @conversation.save!
      cancel_linked_tickets
      saved
    end
  end

  # Ticket so desta conversa: cancelado junto, sempre. Ticket com OUTRAS conversas
  # (`other_conversations_count` > 0): so e' cancelado se quem cancelou escolheu
  # isso (`cancel_ticket_ids`) - a conversa pode ser so um dos assuntos dele.
  def cancel_linked_tickets
    actor = Current.user if Current.user.is_a?(User)
    tickets = cancellable_tickets
    others = other_conversations_counts(tickets)
    chosen = Array(params[:cancel_ticket_ids]).map(&:to_i)

    tickets.each do |ticket|
      next if others.fetch(ticket.id, 0).positive? && chosen.exclude?(ticket.id)

      ticket.cancel!(actor, reason: cancel_reason)
    end
  end

  def cancellable_tickets
    @conversation.tickets.where(status: [:open, :resolved]).order(:id).to_a
  end

  def other_conversations_counts(tickets)
    return {} if tickets.empty?

    TicketConversation.where(ticket_id: tickets.map(&:id)).where.not(conversation_id: @conversation.id).group(:ticket_id).count
  end

  def handle_human_open
    @conversation.with_lock do
      @conversation.assignee_agent_bot = nil
      @conversation.assignee = Current.user if Current.user.agent? && !manual_queue_conversation? && !queue_locked_for_current_user?
      @conversation.save!
    end
  end

  # Uma conversa numa fila de distribuicao manual (ex: triagem por IA,
  # "Suporte N1/N2") so pode ganhar dono por uma escolha explicita - abrir ou
  # reabrir a conversa nao pode reivindicar ela sozinho, senao a fila vira
  # decoracao: quem primeiro olhar a conversa ja fica com ela, fora de
  # qualquer ordem.
  #
  # `queue_id` sozinho nao bastava: um agente pode abrir a conversa ENQUANTO
  # a triagem ainda esta rodando, antes dela definir a fila - nesse instante
  # `queue_id` ainda esta em branco, e o assignee gravado aqui nao e mais
  # desfeito depois (o roteamento so seta time/fila/prioridade, nunca limpa
  # o assignee). Mesma corrida ja corrigida em
  # `AutoAssignmentHandler#pending_flow_automation?` - aqui repetida porque e
  # um controller, nao o mesmo modulo.
  # Conversa numa fila + quem abre nao e' Administrador: abrir/reabrir nunca
  # atribui - so' o "Pegar proximo da fila" (Queues#claim_next).
  def queue_locked_for_current_user?
    @conversation.queue_id.present? && !Current.account_user&.administrator?
  end

  def manual_queue_conversation?
    return true if @conversation.queue_id.present? && @conversation.queue&.manual?

    @conversation.account.automation_rules.where(active: true).any?(&:flow?)
  end

  # BLOQUEIO: o cliente que ja esta sendo atendido por OUTRA pessoa nao pode ser
  # chamado de novo. Sem isso, dois atendentes falavam com o mesmo cliente ao mesmo
  # tempo - e, com a caixa travada em uma conversa so, a mensagem nova caia dentro
  # da conversa de quem ja estava atendendo. Vale para o contato em QUALQUER caixa
  # da conta (o cliente e' o mesmo), so' para conversa ABERTA com responsavel e so'
  # quando o responsavel nao e' quem esta tentando - quem ja atende pode seguir.
  def ensure_contact_not_in_attendance
    return unless Current.user.is_a?(User)

    active = contact_in_attendance_by_someone_else
    return if active.blank?

    render json: {
      error: I18n.t('conversations.in_attendance', agent: active.assignee.name, id: active.display_id),
      code: 'contact_in_attendance',
      conversation_id: active.display_id,
      account_id: active.account_id,
      assignee_name: active.assignee.name
    }, status: :unprocessable_entity
  end

  def contact_in_attendance_by_someone_else
    Conversations::ContactAttendance.new(account: Current.account, contact_id: @contact_inbox.contact_id,
                                         user: Current.user).by_someone_else
  end

  # Cliente que JA chamou e esta esperando sem agente (conversa aberta ou pendente,
  # sem responsavel, nesta caixa): quem inicia a conversa PUXA essa conversa da fila
  # e fica com ela - em vez de abrir uma segunda conversa com o mesmo cliente.
  #
  # A trava da fila continua valendo: quem nao e' Administrador so pode pegar a
  # conversa que e' a PROXIMA da fila (mesma ordem de `Queues#claim_next`); qualquer
  # outra fica para o "Pegar proximo da fila". Sem isso, "iniciar conversa" viraria
  # um jeito de escolher fora de ordem - exatamente o que a trava impede.
  def find_waiting_conversation
    return unless Current.user.is_a?(User)

    @waiting_conversation = Current.account.conversations
                                   .where(inbox_id: @contact_inbox.inbox_id, contact_id: @contact_inbox.contact_id,
                                          assignee_id: nil, status: [:open, :pending])
                                   .order(:created_at, :id).first
    return if @waiting_conversation.blank? || may_take_from_queue?(@waiting_conversation)

    render json: {
      error: I18n.t('conversations.waiting_in_queue', id: @waiting_conversation.display_id),
      code: 'contact_waiting_in_queue',
      conversation_id: @waiting_conversation.display_id,
      account_id: @waiting_conversation.account_id
    }, status: :unprocessable_entity
  end

  def may_take_from_queue?(conversation)
    return true if conversation.queue_id.blank?
    return true if Current.account_user&.administrator?

    next_in_queue_for_current_user&.id == conversation.id
  end

  # Mesmo criterio de `Queues#claim_next`: todas as filas dos Times do agente,
  # maior prioridade primeiro e, na mesma prioridade, quem chamou primeiro.
  def next_in_queue_for_current_user
    queue_ids = Current.account.queues.where(team_id: Current.user.teams.ids).ids
    return if queue_ids.empty?

    Current.account.conversations
           .where(queue_id: queue_ids, assignee_id: nil, status: :open)
           .order(Arel.sql('priority DESC NULLS LAST, created_at ASC, id ASC'))
           .first
  end

  # "Abrir conversa" de dentro de um ticket: o painel manda `ticket_id` junto da criacao.
  def ticket_to_link
    return if params[:ticket_id].blank?

    ticket = Current.account.tickets.find(params[:ticket_id])
    authorize ticket, :update?
    ticket
  end

  def pull_or_build_conversation
    return take_over_waiting_conversation(@waiting_conversation) if @waiting_conversation

    ConversationBuilder.new(params: params, contact_inbox: @contact_inbox).perform
  end

  # Cliente PAUSADO por inatividade (status "Pausada", sem agente) nesta caixa: abrir uma
  # segunda conversa deixava a pausada esquecida e, sem resposta do cliente, a nova tambem
  # era pausada - duas "Pausadas" do mesmo cliente. Recusa e avisa, com o link da conversa:
  # reabrir a pausada (botao Reabrir) retoma o atendimento e avisa o cliente.
  def ensure_contact_not_paused
    return unless Current.user.is_a?(User)
    return if @waiting_conversation

    paused = Current.account.conversations
                    .where(inbox_id: @contact_inbox.inbox_id, contact_id: @contact_inbox.contact_id, status: :snoozed)
                    .where("additional_attributes ->> 'paused_at' IS NOT NULL")
                    .order(created_at: :desc, id: :desc).first
    return if paused.blank?

    render json: {
      error: I18n.t('conversations.paused', id: paused.display_id),
      code: 'contact_paused',
      conversation_id: paused.display_id,
      account_id: paused.account_id
    }, status: :unprocessable_entity
  end

  def take_over_waiting_conversation(conversation)
    conversation.with_lock do
      # Alguem pode ter pegado no meio tempo: nao rouba de quem acabou de assumir.
      if conversation.assignee_id.present? && conversation.assignee_id != Current.user.id
        conversation.errors.add(:base, I18n.t('conversations.in_attendance', agent: conversation.assignee.name, id: conversation.display_id))
        raise ActiveRecord::RecordInvalid, conversation
      end

      conversation.assignee_agent_bot = nil
      conversation.assignee = Current.user
      conversation.status = :open if conversation.pending?
      conversation.save!
    end
    @pulled_from_queue = true
    conversation
  end

  # Chegar aqui so acontece por acao direta de um agente logado (botao "Nova
  # Conversa") - diferente de uma conversa que chega sozinha pelo canal
  # (Whatsapp/Email/API publica), aqui quem fala primeiro e' a empresa. Nao
  # faz sentido o fluxo de automacao (Configuracoes > Automacoes > Fluxo, ex:
  # pedir CNPJ) interromper a resposta do cliente por cima do atendente que
  # ja iniciou a conversa manualmente - ver `AutomationRules::Flow::DispatcherService`.
  def mark_as_agent_initiated(conversation)
    return if conversation.additional_attributes['agent_initiated'].present?

    conversation.additional_attributes['agent_initiated'] = true
    conversation.save!
  end

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation, :show?
  end

  def inbox
    return if params[:inbox_id].blank?

    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end

  def contact
    return if params[:contact_id].blank?

    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def contact_inbox
    @contact_inbox = build_contact_inbox

    # fallback for the old case where we do look up only using source id
    # In future we need to change this and make sure we do look up on combination of inbox_id and source_id
    # and deprecate the support of passing only source_id as the param
    @contact_inbox ||= ::ContactInbox.find_by!(source_id: params[:source_id])
    authorize @contact_inbox.inbox, :show?
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'source_id should be unique' }, status: :unprocessable_entity
  end

  def build_contact_inbox
    return if @inbox.blank? || @contact.blank?

    ContactInboxBuilder.new(
      contact: @contact,
      inbox: @inbox,
      source_id: params[:source_id],
      hmac_verified: hmac_verified?
    ).perform
  end

  def conversation_finder
    @conversation_finder ||= ConversationFinder.new(Current.user, params)
  end

  def assignee?
    @conversation.assignee_id? && Current.user == @conversation.assignee
  end
end

Api::V1::Accounts::ConversationsController.prepend_mod_with('Api::V1::Accounts::ConversationsController')
