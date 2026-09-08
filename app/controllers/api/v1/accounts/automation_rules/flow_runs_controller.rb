# O historico de execucoes de uma automacao: em que etapa cada conversa esta ou
# parou, e por que.
#
# Somente leitura. Uma execucao e o registro do que aconteceu - reescrever isso
# pela API apagaria justamente a trilha que ela existe para guardar.
class Api::V1::Accounts::AutomationRules::FlowRunsController < Api::V1::Accounts::BaseController
  RUNS_PER_PAGE = 25

  before_action :check_authorization
  before_action :fetch_automation_rule

  def index
    @flow_runs = @automation_rule.flow_runs
                                 .includes(:conversation, :ticket)
                                 .order(created_at: :desc)
                                 .page(params[:page])
                                 .per(RUNS_PER_PAGE)
  end

  def show
    @flow_run = @automation_rule.flow_runs.find(params[:id])
    @events = @flow_run.events.chronological
  end

  private

  # A autorizacao e a da automacao: quem pode ver a regra pode ver o que ela fez.
  def check_authorization
    authorize(AutomationRule)
  end

  def fetch_automation_rule
    @automation_rule = Current.account.automation_rules.find(params[:automation_rule_id])
  end
end
