# Encontra o Solicitante dentro da empresa ja identificada.
#
# A regra que isto respeita: o contato do ticket precisa pertencer a empresa
# vinculada. Por isso a busca e sempre dentro de `company.contacts`, e nunca na
# conta inteira.
class AutomationRules::Flow::Steps::FindContact < AutomationRules::Flow::Steps::Base
  def perform
    company = account.companies.find_by(id: run.read_variable('empresa.id'))
    return branch_not_found(reason: 'empresa_ausente') if company.blank?

    contact = match_within(company)
    return branch_not_found(reason: 'nao_encontrado') if contact.blank?

    remember(contact)
    continue(result: { contact_id: contact.id, contact_name: contact.name })
  end

  private

  # Primeiro o contato da propria conversa, quando ele ja e da empresa - e o
  # caso comum de quem ja escreveu antes. So depois pelo nome informado.
  def match_within(company)
    current = conversation.contact
    return current if current.present? && current.company_id == company.id

    name = resolver.value(params[:name_from].presence || 'resposta.nome').to_s.strip
    return if name.blank?

    company.contacts.where('LOWER(name) = ?', name.downcase).first
  end

  def remember(contact)
    run.write_variable('contato.id', contact.id)
    run.write_variable('contato.nome', contact.name)
    run.write_variable('contato.email', contact.email)
  end

  def branch_not_found(reason:)
    target = step.dig('branches', 'not_found')
    return handoff(result: { reason: reason }) if target.blank?

    continue(target, result: { reason: reason })
  end
end
