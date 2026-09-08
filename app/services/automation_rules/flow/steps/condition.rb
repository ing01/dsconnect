# Uma bifurcacao: compara uma variavel e escolhe o caminho.
#
# Os operadores sao os mesmos nomes que as condicoes da automacao ja usam, para
# quem configura nao ter de aprender dois vocabularios.
class AutomationRules::Flow::Steps::Condition < AutomationRules::Flow::Steps::Base
  def perform
    actual = resolver.value(params[:variable])
    matched = compare(actual.to_s, params[:value].to_s)
    target = step.dig('branches', matched ? 'true' : 'false')

    # Sem ramo para o resultado, segue o caminho comum: uma condicao sem saida
    # configurada nao pode travar o fluxo.
    continue(target.presence || step['next'], result: { matched: matched, value: actual })
  end

  private

  def compare(actual, expected)
    case params[:operator].to_s
    when 'not_equal_to' then actual != expected
    when 'contains' then actual.downcase.include?(expected.downcase)
    when 'does_not_contain' then actual.downcase.exclude?(expected.downcase)
    when 'is_present' then actual.present?
    when 'is_not_present' then actual.blank?
    else actual == expected
    end
  end
end
