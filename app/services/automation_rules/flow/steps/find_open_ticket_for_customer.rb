# Evita duplicar Ticket: antes de criar um novo, ve se este contato/empresa
# ja tem um aberto no mesmo Mesa (o `create_ticket` deste fluxo sempre aponta
# para um `team_id` fixo, e e essa a mesma nocao de "canal" usada aqui).
#
# Sem branch `found` configurado, o fluxo so segue por `next` como sempre -
# o admin decide o que fazer (normalmente, ir direto para `create_ticket`).
class AutomationRules::Flow::Steps::FindOpenTicketForCustomer < AutomationRules::Flow::Steps::Base
  def perform
    ticket = matching_scope.order(:created_at).first
    return continue(result: { found: false }) if ticket.blank?

    remember(ticket)
    branch_found(ticket)
  end

  private

  def matching_scope
    scope = account.tickets.operational
                   .where(company_id: run.read_variable('empresa.id'))
                   .where(contact_id: run.read_variable('contato.id'))
                   .where(team_id: params[:team_id])
    window_days = account.helpdesk_open_ticket_window_days.presence
    return scope if window_days.blank?

    scope.where('tickets.created_at >= ?', window_days.to_i.days.ago)
  end

  def remember(ticket)
    run.update!(ticket: ticket)
    run.write_variable('ticket.id', ticket.id)
    run.write_variable('ticket.numero', ticket.display_id)
    run.write_variable('ticket.titulo', ticket.title)
  end

  def branch_found(ticket)
    target = step.dig('branches', 'found')
    result = { found: true, ticket_id: ticket.id }
    return continue(result: result) if target.blank?

    continue(target, result: result)
  end
end
