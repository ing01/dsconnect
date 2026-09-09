# Verifica o contato para a Empresa ja identificada (tipicamente usada no
# Widget, onde nao ha telefone para reconhecer o contato automaticamente):
#
# - nome/e-mail ja coletados (perguntados nesta conversa, ou que o Widget ja
#   sabia antes de comecar) e o contato ainda nao tem nada salvo -> so
#   registra e vincula a Empresa, sem bloquear o atendimento;
# - o e-mail informado ja pertence a OUTRO contato desta conta -> normalmente
#   e a mesma pessoa com um cadastro anterior (outro canal, ou uma visita
#   anterior ao Widget) - funde os dois e segue com o contato existente,
#   igual a tela de "Mesclar contatos" ja faz;
# - o contato ja tinha nome/e-mail salvo e o que veio agora diverge do que
#   ja existia -> nao assume que virou outra pessoa sozinho, cai no ramo
#   `inconsistent`.
class AutomationRules::Flow::Steps::LinkContactToCompany < AutomationRules::Flow::Steps::Base
  def perform
    name = collected_name
    email = collected_email
    return branch_inconsistent if inconsistent?(name, email)

    merge_into_existing_contact_by_email!(email)

    company_id = run.read_variable('empresa.id')
    return branch_inconsistent unless ensure_membership(company_id)
    return branch_inconsistent unless update_contact_details(name, email)

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

  # So compara contra o que ESTE contato ja tinha salvo - um e-mail que bate
  # com OUTRO contato da conta e tratado a parte (fusao), nao como
  # inconsistencia.
  def inconsistent?(name, email)
    existing_name = contact.name.to_s.strip
    existing_email = contact.email.to_s.strip.downcase
    return true if existing_name.present? && name.present? && !existing_name.casecmp?(name.to_s.strip)
    return true if existing_email.present? && email.present? && existing_email != email.to_s.strip.downcase

    false
  end

  # So tenta a fusao quando este contato AINDA NAO TEM e-mail proprio - se ja
  # tinha um diferente do informado, isso ja foi pego por `inconsistent?`
  # acima, e fundir os dois seria assumir sozinho que viraram a mesma pessoa
  # sem base nenhuma.
  def merge_into_existing_contact_by_email!(email)
    return if email.blank? || contact.email.present?

    existing = account.contacts.from_email(email)
    return if existing.blank? || existing.id == contact.id

    ContactMergeAction.new(account: account, base_contact: existing, mergee_contact: contact).perform
    # O contato antigo (o do Widget, sem historico ainda) foi destruido pela
    # fusao - recarrega a Conversation para que `contact`/`contact_id`
    # passem a apontar para o sobrevivente, e nao para o objeto em memoria
    # que ja nao existe mais no banco.
    conversation.reload
  end

  # Aditivo, nunca troca a empresa primaria de quem ja tem uma - um contato
  # pode trabalhar em mais de uma Empresa.
  #
  # `update` (sem `!`) de proposito: uma falha de validacao aqui nao pode
  # derrubar a execucao inteira sem avisar ninguem - vira um `inconsistent`
  # normal, que o admin decide se vira handoff ou uma etapa de confirmacao.
  def ensure_membership(company_id)
    return true if company_id.blank?

    contact.company_contacts.find_or_create_by!(company_id: company_id)
    return true if contact.company_id.present?

    contact.update(company_id: company_id)
  end

  # So preenche o que estava em branco - nunca sobrescreve um valor que ja
  # existia (isso ja teria sido resolvido por `inconsistent?` ou pela fusao
  # acima). Continua existindo como rede de seguranca para qualquer outra
  # validacao do Contact que nao seja o e-mail duplicado.
  def update_contact_details(name, email)
    updates = {}
    updates[:name] = name if name.present? && contact.name.blank?
    updates[:email] = email if email.present? && contact.email.blank?
    return true if updates.empty?

    contact.update(updates)
  end

  def remember(name, email)
    run.write_variable('contato.id', conversation.contact_id)
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
