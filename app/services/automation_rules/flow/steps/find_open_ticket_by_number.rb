# Valida o numero de ticket que o cliente informou antes de vincular a
# conversa a ele - nunca confia no numero sozinho.
#
# Um ticket so serve de vinculo quando: existe, esta aberto (um ticket
# encerrado nao reabre so por chegar mensagem nova - a automacao trata isso
# como "nao encontrado" e segue para criar um novo, conforme a regra pedida),
# e pertence ao contato ou a Empresa que a triagem ja identificou.
class AutomationRules::Flow::Steps::FindOpenTicketByNumber < AutomationRules::Flow::Steps::Base
  def perform
    display_id = resolver.value(params[:number_from].presence || 'resposta.numero_ticket').to_s.gsub(/\D/, '')
    return branch_not_found(reason: 'numero_ausente') if display_id.blank?

    ticket = account.tickets.find_by(display_id: display_id)
    return branch_not_found(reason: 'nao_encontrado', numero: display_id) if ticket.blank?
    return branch_not_found(reason: 'encerrado', numero: display_id) unless ticket.open?
    return branch_not_owned(ticket) unless owned_by_customer?(ticket)

    remember(ticket)
    continue(result: { ticket_id: ticket.id, display_id: ticket.display_id })
  end

  private

  # Um ticket sem contato nem empresa nao tem contra o que validar, e por
  # isso nao pode ser reivindicado por numero - so contatos/empresas ja
  # vinculados de outra forma.
  def owned_by_customer?(ticket)
    return false if ticket.contact_id.blank? && ticket.company_id.blank?
    return false if ticket.contact_id.present? && ticket.contact_id != conversation.contact_id
    return false if ticket.company_id.present? && !conversation.contact.company_ids.include?(ticket.company_id)

    true
  end

  # O ponto inteiro desta etapa e vincular a conversa ao ticket - sem isso,
  # so teria confirmado que ele existe, sem realizar o vinculo pedido.
  def remember(ticket)
    ticket.ticket_conversations.find_or_create_by!(conversation_id: conversation.id)
    run.update!(ticket: ticket)
    run.write_variable('ticket.id', ticket.id)
    run.write_variable('ticket.numero', ticket.display_id)
    run.write_variable('ticket.titulo', ticket.title)
  end

  def branch_not_found(reason:, **extra)
    target = step.dig('branches', 'not_found')
    return handoff(result: { reason: reason, **extra }) if target.blank?

    continue(target, result: { reason: reason, **extra })
  end

  def branch_not_owned(ticket)
    target = step.dig('branches', 'not_owned')
    result = { reason: 'nao_pertence', ticket_id: ticket.id }
    return handoff(result: result) if target.blank?

    continue(target, result: result)
  end
end
