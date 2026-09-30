# Identifica a Empresa do contato automaticamente, e so pergunta quando ha
# ambiguidade de verdade.
#
# Um contato com UMA UNICA Empresa vinculada (o caso comum do Portal do
# Cliente, onde quem escreve ja esta autenticado) e' identificado na hora, sem
# nenhuma pergunta - perguntar "e' essa empresa mesmo?" para quem so tem uma
# opcao e' atrito sem propósito. So quando ha MAIS de uma Empresa vinculada e'
# que a escolha e' de verdade e o cliente precisa dizer qual.
#
# Um contato sem nenhuma Empresa vinculada (cliente novo pelo WhatsApp, por
# exemplo) nao tem o que listar - segue pelo ramo `no_companies`, que o admin
# tipicamente aponta para um `ask` + `find_company` coletando o CNPJ.
#
# Se o cliente recusar a(s) empresa(s) apresentada(s) ("nao", "outra
# empresa"...) ou a resposta nao bater com nenhuma opcao depois de algumas
# tentativas, segue pelo ramo `not_selected` - o admin aponta para o mesmo
# tipo de coleta de CNPJ usada em `no_companies`, sem travar o cliente num
# loop pedindo a mesma escolha para sempre.
#
# Executada duas vezes, como a `Ask`: sem mensagem, pergunta e espera; com
# mensagem, tenta casar a resposta. Com UMA empresa so, nem chega a "esperar":
# resolve e segue no mesmo passo.
class AutomationRules::Flow::Steps::ListCompanies < AutomationRules::Flow::Steps::Base
  MAX_ATTEMPTS = 2
  NEGATIVE_ANSWER = /\A\s*(n[aã]o\b|nenhuma?\b|outra\s+empresa)/i

  def perform
    return branch_no_companies if companies.empty?
    return auto_select_only_company if companies.one?

    return ask_choice if message.blank?

    receive_choice
  end

  private

  def auto_select_only_company
    company = companies.first
    remember(company)
    continue(result: { company_id: company.id, auto_selected: true })
  end

  def branch_no_companies
    target = step.dig('branches', 'no_companies')
    return handoff(result: { reason: 'sem_empresas' }) if target.blank?

    continue(target, result: { reason: 'sem_empresas' })
  end

  def branch_not_selected(reason:)
    target = step.dig('branches', 'not_selected')
    result = { reason: reason }
    return handoff(result: result) if target.blank?

    continue(target, result: result)
  end

  def companies
    @companies ||= conversation.contact.companies.order(:name).to_a
  end

  def ask_choice
    say(list_message)
    wait(step['id'], result: { asked: companies.map(&:name) })
  end

  # So chega aqui com mais de uma Empresa: com uma so, `perform` resolve antes
  # de haver mensagem para montar.
  def list_message
    return rendered(:content) if rendered(:content).present?

    multiple_companies_message
  end

  def multiple_companies_message
    options = companies.each_with_index.map { |company, index| "#{index + 1}. #{company.name}" }
    "Pronto! Vi aqui que seu contato está vinculado a estas empresas. Gostaria de falar sobre qual delas?\n" \
      "#{options.join("\n")}"
  end

  def receive_choice
    answer = message.content.to_s.strip
    return branch_not_selected(reason: 'recusada') if negative?(answer)

    company = match(answer)
    return retry_or_escape if company.blank?

    remember(company)
    continue(result: { company_id: company.id })
  end

  def negative?(answer)
    answer.match?(NEGATIVE_ANSWER)
  end

  def match(answer)
    by_index(answer) || by_cnpj(answer) || by_name(answer)
  end

  def by_index(answer)
    return nil unless answer.match?(/\A\d+\z/)

    index = answer.to_i
    return nil unless index.between?(1, companies.size)

    companies[index - 1]
  end

  def by_cnpj(answer)
    digits = answer.gsub(/\D/, '')
    return nil if digits.blank?

    companies.find { |company| company.cnpj.present? && company.cnpj == digits }
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

  # Depois de algumas tentativas sem bater com nenhuma empresa listada, para
  # de insistir do mesmo jeito (senao vira loop infinito) e cai no mesmo ramo
  # de "quero outra empresa" - o cliente informa o CNPJ diretamente.
  def retry_or_escape
    return branch_not_selected(reason: 'nao_reconhecida') if attempts >= MAX_ATTEMPTS

    increment_attempts!
    say(I18n.t('automations.flow.list_companies.retry'))
    wait(step['id'], result: { rejected: true })
  end

  def attempts_key
    "list_companies.#{step['id']}.attempts"
  end

  def attempts
    run.read_variable(attempts_key).to_i
  end

  def increment_attempts!
    run.write_variable(attempts_key, attempts + 1)
  end
end
