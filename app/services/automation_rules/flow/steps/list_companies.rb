# Quando o contato tem mais de uma Empresa vinculada, lista as opcoes e
# espera a escolha - por numero ou pelo nome digitado. So cai numa
# interpretacao mais livre (fora desta etapa) se nem numero nem nome baterem
# de forma exata o bastante.
#
# Um contato sem nenhuma Empresa vinculada (cliente novo pelo WhatsApp, por
# exemplo) nao tem o que listar - segue pelo ramo `no_companies`, que o admin
# tipicamente aponta para um `ask` + `find_company` coletando o CNPJ.
#
# Executada duas vezes, como a `Ask`: sem mensagem, pergunta e espera; com
# mensagem, tenta casar a resposta.
class AutomationRules::Flow::Steps::ListCompanies < AutomationRules::Flow::Steps::Base
  def perform
    return branch_no_companies if companies.empty?

    return ask_choice if message.blank?

    receive_choice
  end

  private

  def branch_no_companies
    target = step.dig('branches', 'no_companies')
    return handoff(result: { reason: 'sem_empresas' }) if target.blank?

    continue(target, result: { reason: 'sem_empresas' })
  end

  def companies
    @companies ||= conversation.contact.companies.order(:name).to_a
  end

  def ask_choice
    say(list_message)
    wait(step['id'], result: { asked: companies.map(&:name) })
  end

  def list_message
    intro = rendered(:content).presence || I18n.t('automations.flow.list_companies.prompt')
    options = companies.each_with_index.map { |company, index| "#{index + 1}. #{company.name}" }
    "#{intro}\n#{options.join("\n")}"
  end

  def receive_choice
    answer = message.content.to_s.strip
    company = match(answer)
    return retry_choice if company.blank?

    remember(company)
    continue(result: { company_id: company.id })
  end

  def match(answer)
    by_index(answer) || by_name(answer)
  end

  def by_index(answer)
    return nil unless answer.match?(/\A\d+\z/)

    index = answer.to_i
    return nil unless index.between?(1, companies.size)

    companies[index - 1]
  end

  def by_name(answer)
    return nil if answer.blank?

    companies.find { |company| company.name.casecmp?(answer) } ||
      companies.find { |company| company.name.downcase.include?(answer.downcase) }
  end

  def remember(company)
    run.write_variable('empresa.id', company.id)
    run.write_variable('empresa.nome', company.name)
    run.write_variable('empresa.cnpj', company.cnpj)
    run.write_variable('empresa.nivel', company.client_level)
    run.write_variable(save_as, company.name)
  end

  def save_as
    key = params[:save_as].presence || 'empresa_escolhida'
    key.start_with?('resposta.') ? key : "resposta.#{key}"
  end

  def retry_choice
    say(I18n.t('automations.flow.list_companies.retry'))
    wait(step['id'], result: { rejected: true })
  end
end
