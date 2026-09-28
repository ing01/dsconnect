# Liga o evento de "ticket mudou de Estagio" a Automacao de Estagio
# configurada na coluna de destino (TicketColumn#automation_actions,
# Configuracoes > Estagios).
#
# `ticket.moved` ja dispara hoje (TicketBroadcastable) toda vez que
# `ticket_column_id` muda, seja por drag-and-drop no Kanban
# (TicketsController#move) ou por Tickets::TransferService - este listener so
# precisava ser adicionado, nao um hook novo.
class TicketColumnAutomationListener < BaseListener
  # `move_parent_to_column` faz um Estagio de automacao mover outro ticket, cujo
  # proprio `move_to!` dispara `ticket.moved` de novo, SINCRONAMENTE, reentrando
  # neste mesmo metodo antes do primeiro `perform` terminar. Duas regras que se
  # apontam de volta uma pra outra (configuracao errada, nao um bug) virariam
  # recursao infinita sem este teto - por thread, porque toda a cadeia roda no
  # mesmo request/job do pontapé inicial.
  MAX_AUTOMATION_CHAIN_DEPTH = 5

  def ticket_moved(event)
    ticket, account = extract_ticket_and_account(event)
    return if ticket.blank?

    column = ticket.ticket_column
    return if column.blank? || !column.automations_enabled? || column.automation_actions.blank?

    run_with_depth_guard(account) do
      Tickets::ColumnAutomationService.new(ticket: ticket, ticket_column: column).perform
    end
  end

  private

  def run_with_depth_guard(account)
    depth = Thread.current[:ticket_column_automation_depth] || 0

    if depth >= MAX_AUTOMATION_CHAIN_DEPTH
      ChatwootExceptionTracker.new(
        StandardError.new('Automation de Estagio interrompida - profundidade maxima atingida (possivel ciclo entre Estagios)'),
        account: account
      ).capture_exception
      return
    end

    Thread.current[:ticket_column_automation_depth] = depth + 1
    yield
  ensure
    Thread.current[:ticket_column_automation_depth] = depth
  end
end
