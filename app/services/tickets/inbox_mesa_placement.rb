# Onde entra o Ticket que nasce de uma conversa: na Mesa da Fila padrao da
# CAIXA de entrada. Caixa Comercial (fila Comercial) -> Mesa Comercial; caixa
# Especialista -> Mesa Especialista. Antes, todo ticket automatico ia para a
# primeira Mesa da conta (Suporte), ou para a Mesa fixa da etapa da automacao,
# qualquer que fosse a caixa (pedido da Ingrid, 2026-11-26).
#
# Sem Fila padrao ativa na caixa (ou com uma Mesa sem Estagio), devolve `{}` e
# quem chama segue com a Mesa que ja usava.
class Tickets::InboxMesaPlacement
  pattr_initialize [:conversation!]

  def team
    @team ||= conversation.inbox_default_queue&.team
  end

  # A categoria pedida so' vale se for desta Mesa; senao, a primeira dela -
  # categoria e' obrigatoria e quem atende troca depois.
  def attributes(ticket_category_id: nil)
    return {} if team.blank? || ticket_column.blank?

    category = team.ticket_categories.find_by(id: ticket_category_id) || team.ticket_categories.first
    { team_id: team.id, ticket_column_id: ticket_column.id, ticket_category_id: category&.id }.compact
  end

  private

  # Mesmo Estagio de entrada dos outros tickets automaticos: o `pending` da
  # Mesa, ou o primeiro quando ela nao tiver um.
  def ticket_column
    @ticket_column ||= team.ticket_columns.find_by(kind: 'pending') || team.ticket_columns.first
  end
end
