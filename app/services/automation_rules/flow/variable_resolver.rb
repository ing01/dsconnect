# Troca `{{empresa.nome}}` pelo valor que a execucao ja coletou.
#
# Le so o que esta guardado na execucao. O que as etapas descobrem - a empresa
# encontrada, o contato, o ticket criado - e escrito nas variaveis quando
# acontece, entao aqui nao ha consulta ao banco nem regra de negocio: e
# substituicao de texto sobre o que ja se sabe.
class AutomationRules::Flow::VariableResolver
  PATTERN = /\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}/

  def initialize(run)
    @run = run
  end

  def render(template)
    return '' if template.blank?

    template.to_s.gsub(PATTERN) { |_match| lookup(Regexp.last_match(1)).to_s }
  end

  # Uma variavel isolada, sem template em volta: e assim que uma condicao le o
  # valor que vai comparar.
  def value(path)
    lookup(path)
  end

  private

  # Variavel nao preenchida vira texto vazio, e nao o `{{...}}` cru: uma mensagem
  # com chaves no meio parece defeito para quem esta do outro lado da conversa.
  def lookup(path)
    @run.read_variable(path)
  end
end
