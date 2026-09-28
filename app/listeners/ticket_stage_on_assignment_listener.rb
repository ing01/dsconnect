# Move o(s) Ticket(s) vinculados a uma Conversation para o Estagio "Em
# atendimento" (TicketColumn kind `in_progress`) assim que a conversa ganha um
# responsavel - pegar da fila, se auto-atribuir ou ser atribuido por um
# Administrador contam igual (AssignmentHandler dispara `assignee.changed`
# nos tres casos). So a Mesa que quiser esse comportamento precisa marcar uma
# das suas colunas com esse kind (Configuracoes > Estagios); sem isso, e' um
# no-op silencioso - nenhuma automacao nova pra quem nao configurou nada.
class TicketStageOnAssignmentListener < BaseListener
  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    return if conversation.assignee.blank?

    conversation.tickets.open.triaged.each { |ticket| move_ticket_to_in_progress(ticket, account) }
  end

  private

  # Cada ticket roda isolado: uma coluna alvo com regra que o ticket nao
  # cumpre (ex: `require_assignee` sem o ticket ter um) nunca pode travar a
  # atribuicao da conversa em si - so fica registrado no rastreador de excecoes,
  # igual Tickets::ColumnAutomationService ja faz pra Automacao de Estagio.
  def move_ticket_to_in_progress(ticket, account)
    target_column = ticket.team.ticket_columns.find_by(kind: 'in_progress')
    return if target_column.blank? || ticket.ticket_column_id == target_column.id

    ticket.move_to!(ticket_column: target_column, position: next_position(target_column))
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
  end

  def next_position(column)
    (column.tickets.maximum(:position) || -1) + 1
  end
end
