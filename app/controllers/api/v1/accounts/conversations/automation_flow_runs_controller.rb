# Historico de execucoes da triagem por etapas sobre esta conversa - onde
# parou, o que decidiu, e o erro de cada etapa. Existe para poder diagnosticar
# um fluxo que travou sem precisar de acesso a console/log do servidor -
# `AutomationFlowRunEvent` ja registra tudo isso, so faltava uma tela.
class Api::V1::Accounts::Conversations::AutomationFlowRunsController < Api::V1::Accounts::Conversations::BaseController
  def index
    @runs = @conversation.automation_flow_runs
                          .includes(:automation_rule, :events)
                          .order(created_at: :desc)
  end
end
