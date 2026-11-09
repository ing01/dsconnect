# Executa uma TicketBulkOperation: um ticket por vez, cada um na sua transacao,
# com permissao e estado revalidados na hora (o ticket pode ter mudado entre o
# pedido e a execucao). Um ticket com problema nunca derruba os outros - o
# resultado de cada um fica no item, para o relatorio.
class Tickets::BulkOperations::Runner
  Handlers = Tickets::BulkOperations::Handlers

  # Qual regra da TicketPolicy vale para cada acao.
  POLICY_QUERY = {
    'stage' => :move?, 'team' => :move?, 'assignee' => :assign?, 'resolve' => :resolve?, 'close' => :close?,
    'cancel' => :cancel?, 'reopen' => :reopen?, 'comment' => :show?
  }.freeze

  pattr_initialize [:operation!]

  def perform
    operation.update!(status: :running, started_at: Time.current)
    prepare_customer_messages
    operation.items.pending.order(:id).find_each.with_index do |item, index|
      process(item)
      refresh_counters if (index % 10).zero?
    end
    finish(:completed)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: operation.account).capture_exception
    finish(:failed)
  end

  private

  def user
    @user ||= operation.user
  end

  def action
    operation.action
  end

  def params
    operation.params
  end

  def undo?
    operation.undo_of_id.present?
  end

  def process(item)
    ticket = operation.account.tickets.find_by(id: item.ticket_id)
    return record(item, :skipped, 'not_found', I18n.t('tickets.bulk.reasons.not_found')) if ticket.nil?

    unless permitted?(ticket)
      return record(item, :skipped, 'forbidden', I18n.t('tickets.bulk.reasons.forbidden'))
    end

    snapshot = nil
    ticket.with_lock { snapshot = apply(ticket, item) }
    item.update!(before: snapshot || {})
    record(item, :succeeded)
  rescue Handlers::Skip => e
    record(item, :skipped, e.code, e.message)
  rescue ActiveRecord::RecordInvalid => e
    record(item, :failed, 'invalid', e.message)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: operation.account).capture_exception
    record(item, :failed, 'error', e.message.truncate(250))
  end

  def apply(ticket, item)
    return Handlers.undo(operation.params['original_action'], ticket, item.before) if undo?
    return send_customer_message(ticket) if action == 'customer_message'

    Handlers.apply(action, ticket, user, params)
  end

  def permitted?(ticket)
    query = undo? ? :update? : POLICY_QUERY.fetch(action, :update?)
    TicketPolicy.new(user_context, ticket).public_send(query)
  end

  def user_context
    @user_context ||= {
      user: user, account: operation.account,
      account_user: operation.account.account_users.find_by(user_id: user.id)
    }
  end

  def record(item, outcome, code = nil, message = nil)
    item.update!(outcome: outcome, reason_code: code, reason_message: message)
  end

  def refresh_counters
    counts = operation.items.group(:outcome).count
    operation.update!(succeeded: counts['succeeded'].to_i, skipped: counts['skipped'].to_i, failed: counts['failed'].to_i)
  end

  def finish(status)
    refresh_counters
    operation.update!(status: status, finished_at: Time.current)
  end

  # --- Comunicacao ao cliente, consolidada por solicitante -----------------

  # Quais tickets cada solicitante tem na operacao: a unica mensagem de cada um
  # lista todos eles.
  def prepare_customer_messages
    return unless action == 'customer_message'

    @sent_contacts = Set.new
    @tickets_by_contact = Hash.new { |hash, key| hash[key] = [] }
    operation.account.tickets.where(id: operation.items.select(:ticket_id)).includes(:contact, conversations: :contact).find_each do |ticket|
      contact = ticket.requester_contact
      @tickets_by_contact[contact.id] << ticket.display_id if contact&.email.present?
    end
  end

  # O primeiro ticket de cada solicitante envia o e-mail (com a lista de todos);
  # nos demais a mensagem so e registrada, sem novo e-mail.
  def send_customer_message(ticket)
    contact = ticket.requester_contact
    raise Handlers::Skip.new('no_requester_email', I18n.t('tickets.bulk.reasons.no_requester_email')) if contact&.email.blank?

    first = @sent_contacts.exclude?(contact.id)
    body = first ? consolidated_body(contact, params['body']) : params['body']
    Tickets::CustomerCommunicationService.new(
      ticket: ticket, user: user, body: body, closing: false, notify_customer: first && params['notify_customer'] != false
    ).perform
    @sent_contacts << contact.id
    nil
  end

  def consolidated_body(contact, body)
    numbers = @tickets_by_contact[contact.id]
    return body if numbers.size < 2

    "#{body}\n\n#{I18n.t('tickets.bulk.related_tickets', numbers: numbers.sort.map { |n| "##{n}" }.join(', '))}"
  end
end
