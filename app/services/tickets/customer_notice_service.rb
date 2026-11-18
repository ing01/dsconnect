# Envia ao cliente as mensagens automaticas (TicketCustomerNoticeRule) que
# combinam com o que acabou de acontecer com o ticket: entrou num Estagio e/ou
# passou para outra Mesa.
#
# Cada regra roda isolada - uma que falha (SMTP fora, texto invalido) vai para o
# rastreador de excecoes e nao impede as demais. Sem e-mail do solicitante nao
# ha para quem escrever, entao nada e enviado (o mesmo criterio da acao
# "enviar mensagem ao cliente" da Automacao de Estagio).
class Tickets::CustomerNoticeService
  pattr_initialize [:ticket!, :column_id!, :from_team_id, :to_team_id]

  def perform
    return if ticket.requester_contact&.email.blank?

    rules.each { |rule| send_notice(rule) }
  end

  private

  def rules
    TicketCustomerNoticeRule.matching(
      account_id: ticket.account_id, column_id: column_id,
      from_team_id: from_team_id, to_team_id: to_team_id
    ).ordered
  end

  def previous_team
    @previous_team ||= Team.find_by(id: from_team_id) if from_team_id.present?
  end

  def send_notice(rule)
    Tickets::CustomerCommunicationService.new(
      ticket: ticket, user: nil, closing: false, notify_customer: rule.notify_customer,
      body: rule.render_body(ticket, previous_team: previous_team)
    ).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: ticket.account).capture_exception
  end
end
