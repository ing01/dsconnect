# Procura a Empresa ja cadastrada pelo CNPJ coletado.
#
# Nunca cria: criar empresa a partir de um numero digitado no chat e decisao de
# cadastro, nao de triagem. Quando nao acha, o fluxo segue pelo ramo
# `not_found`, que o admin configura como quiser.
class AutomationRules::Flow::Steps::FindCompany < AutomationRules::Flow::Steps::Base
  def perform
    cnpj = resolver.value(params[:cnpj_from].presence || 'resposta.cnpj').to_s.gsub(/\D/, '')
    return branch_not_found(reason: 'cnpj_ausente') if cnpj.blank?

    company = account.companies.find_by(cnpj: cnpj)
    return branch_not_found(reason: 'nao_encontrada', cnpj: cnpj) if company.blank?

    remember(company)
    continue(result: { company_id: company.id, company_name: company.name })
  end

  private

  def remember(company)
    run.write_variable('empresa.id', company.id)
    run.write_variable('empresa.nome', company.name)
    run.write_variable('empresa.cnpj', company.cnpj)
    run.write_variable('empresa.nivel', company.client_level)
    link_contact(company)
  end

  # Achar a Empresa pelo CNPJ que o proprio cliente informou E' o ato de
  # identifica-lo - sem vincular aqui, o Contact continua sem nenhuma Empresa
  # associada (so a variavel `empresa.id` do fluxo sabe), e um `create_ticket`
  # mais adiante falha na validacao `contact_belongs_to_company` do Ticket
  # (`contact.company_ids` nao inclui essa empresa) - exatamente o caso de
  # todo contato novo do WhatsApp que se identifica por CNPJ.
  def link_contact(company)
    contact = conversation.contact
    return if contact.blank?

    contact.company_contacts.find_or_create_by!(company_id: company.id)
    contact.update(company_id: company.id) if contact.company_id.blank?
  end

  # Sem ramo configurado o fluxo nao pode simplesmente seguir como se tivesse
  # achado: entrega para uma pessoa.
  def branch_not_found(reason:, **extra)
    target = step.dig('branches', 'not_found')
    return handoff(result: { reason: reason, **extra }) if target.blank?

    continue(target, result: { reason: reason, **extra })
  end
end
