# Mensagens automaticas ao cliente - Configuracoes > Tickets > Mensagens ao
# cliente. Cada regra diz: "quando o ticket entrar neste Estagio (ou passar para
# esta Mesa), envie este texto ao solicitante".
class Api::V1::Accounts::TicketCustomerNoticeRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_rule, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @rules = Current.account.ticket_customer_notice_rules.ordered
  end

  def create
    @rule = Current.account.ticket_customer_notice_rules.create!(rule_params)
    render 'show'
  end

  def update
    @rule.update!(rule_params)
    render 'show'
  end

  def destroy
    @rule.destroy!
    head :ok
  end

  private

  def fetch_rule
    @rule = Current.account.ticket_customer_notice_rules.find(params[:id])
  end

  def check_authorization(model = nil)
    super(model || @rule || TicketCustomerNoticeRule)
  end

  def rule_params
    params.require(:ticket_customer_notice_rule)
          .permit(:kind, :name, :ticket_column_id, :team_id, :from_team_id, :body, :notify_customer, :active)
  end
end
