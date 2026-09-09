class Api::V1::Accounts::CompanyCategoriesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :check_authorization

  def index
    @company_categories = Current.account.company_categories.ordered_by_name
  end

  def create
    @company_category = Current.account.company_categories.build(company_category_params)
    @company_category.save!
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def company_category_params
    params.require(:company_category).permit(:name)
  end
end
