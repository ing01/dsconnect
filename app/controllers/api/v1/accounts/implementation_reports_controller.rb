class Api::V1::Accounts::ImplementationReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def hours_summary
    render json: V2::Reports::Implementation::HoursSummaryBuilder.new(account: Current.account, params: filter_params).build
  end

  def monthly
    render json: V2::Reports::Implementation::MonthlyReportBuilder.new(account: Current.account, params: filter_params).build
  end

  def by_implementer
    render json: V2::Reports::Implementation::ImplementerReportBuilder.new(account: Current.account, params: filter_params).build
  end

  def by_module
    render json: V2::Reports::Implementation::ModuleReportBuilder.new(account: Current.account, params: filter_params).build
  end

  def incidence
    render json: V2::Reports::Implementation::IncidenceReportBuilder.new(account: Current.account, params: filter_params).build
  end

  def complexity
    render json: V2::Reports::Implementation::ComplexityScoreBuilder.new(account: Current.account, params: filter_params).build
  end

  private

  def check_authorization
    authorize :implementation_report, :view?
  end

  def filter_params
    params.permit(
      :since, :until, :date_field, :implementer_id, :project_module_id, :stage, :team_id, :search
    ).to_h.symbolize_keys
  end
end
