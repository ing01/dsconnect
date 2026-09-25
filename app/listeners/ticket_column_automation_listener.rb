# Liga o evento de "ticket mudou de Estagio" a Automacao de Estagio
# configurada na coluna de destino (TicketColumn#automation_actions,
# Configuracoes > Estagios).
#
# `ticket.moved` ja dispara hoje (TicketBroadcastable) toda vez que
# `ticket_column_id` muda, seja por drag-and-drop no Kanban
# (TicketsController#move) ou por Tickets::TransferService - este listener so
# precisava ser adicionado, nao um hook novo.
class TicketColumnAutomationListener < BaseListener
  def ticket_moved(event)
    ticket, = extract_ticket_and_account(event)
    return if ticket.blank?

    column = ticket.ticket_column
    return if column.blank? || !column.automations_enabled? || column.automation_actions.blank?

    Tickets::ColumnAutomationService.new(ticket: ticket, ticket_column: column).perform
  end
end
