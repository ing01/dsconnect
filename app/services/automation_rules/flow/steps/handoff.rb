# Encerra a triagem e deixa o atendimento para uma pessoa.
#
# E o destino de todo caminho que a automacao nao sabe resolver: melhor entregar
# a um atendente do que seguir adiante com dado faltando.
class AutomationRules::Flow::Steps::Handoff < AutomationRules::Flow::Steps::Base
  def perform
    say(rendered(:content)) if params[:content].present?
    handoff(result: { reason: params[:reason] })
  end
end
