class Api::V1::Accounts::ProductGroupsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :check_authorization
  before_action :fetch_product_group, only: [:update, :destroy]

  def index
    @product_groups = Current.account.product_groups.includes(:products).ordered_by_name
  end

  def create
    @product_group = Current.account.product_groups.build(product_group_params)
    @product_group.save!
  end

  def update
    @product_group.update!(product_group_params)
  end

  def destroy
    @product_group.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_product_group
    @product_group = Current.account.product_groups.find(params[:id])
  end

  def product_group_params
    params.require(:product_group).permit(:name, :total_value_mode, :total_value)
  end
end
