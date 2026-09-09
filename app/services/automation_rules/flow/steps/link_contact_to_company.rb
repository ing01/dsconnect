# Verifica o contato para a Empresa ja identificada (tipicamente usada no
# Widget, onde nao ha telefone para reconhecer o contato automaticamente):
#
# - nome/e-mail ja coletados (perguntados nesta conversa, ou que o Widget ja
#   sabia antes de comecar) e o contato ainda nao tem nada salvo -> so
#   registra e vincula a Empresa, sem bloquear o atendimento;
# - o contato ja tinha nome/e-mail salvo e o que veio agora diverge -> nao
#   assume que virou outra pessoa sozinho, cai no ramo `inconsistent`.
class AutomationRules::Flow::Steps::LinkContactToCompany < AutomationRules::Flow::Steps::Base
  def perform
    name = collected_name
    email = collected_email
    return branch_inconsistent if inconsistent?(name, email)

    company_id = run.read_variable('empresa.id')
    ensure_membership(company_id)
    update_contact_details(name, email)
    remember(name, email)

    continue(result: { contact_id: conversation.contact_id })
  end

  private

  def contact
    conversation.contact
  end

  # `resposta.*` quando a etapa `ask` acabou de perguntar; `contato.*` quando
  # o Widget/pre-chat ja sabia e a pergunta foi pulada (ver `is_present` no
  # `condition` antes desta etapa).
  def collected_name
    resolver.value('resposta.nome').presence || run.read_variable('contato.nome')
  end

  def collected_email
    resolver.value('resposta.email').presence || run.read_variable('contato.email')
  end

  def inconsistent?(name, email)
    existing_name = contact.name.to_s.strip
    existing_email = contact.email.to_s.strip.downcase
    return true if existing_name.present? && name.present? && !existing_name.casecmp?(name.to_s.strip)
    return true if existing_email.present? && email.present? && existing_email != email.to_s.strip.downcase

    false
  end

  # Aditivo, nunca troca a empresa primaria de quem ja tem uma - um contato
  # pode trabalhar em mais de uma Empresa.
  def ensure_membership(company_id)
    return if company_id.blank?

    contact.company_contacts.find_or_create_by!(company_id: company_id)
    contact.update!(company_id: company_id) if contact.company_id.blank?
  end

  # So preenche o que estava em branco - nunca sobrescreve um valor que ja
  # existia (isso ja teria sido pego pela checagem de inconsistencia acima).
  def update_contact_details(name, email)
    updates = {}
    updates[:name] = name if name.present? && contact.name.blank?
    updates[:email] = email if email.present? && contact.email.blank?
    contact.update!(updates) if updates.any?
  end

  def remember(name, email)
    run.write_variable('contato.nome', name) if name.present?
    run.write_variable('contato.email', email) if email.present?
  end

  def branch_inconsistent
    target = step.dig('branches', 'inconsistent')
    result = { reason: 'informacoes_inconsistentes' }
    return handoff(result: result) if target.blank?

    continue(target, result: result)
  end
end
