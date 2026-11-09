class Api::V1::Accounts::CompanyNichesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :check_authorization

  def index
    @company_niches = Current.account.company_niches.ordered_by_name
  end

  def create
    @company_niche = Current.account.company_niches.build(company_niche_params)
    @company_niche.save!
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def company_niche_params
    params.require(:company_niche).permit(:name)
  end
end
