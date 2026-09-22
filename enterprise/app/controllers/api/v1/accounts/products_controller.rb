class Api::V1::Accounts::ProductsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :check_authorization
  before_action :fetch_product, only: [:update, :destroy]

  def index
    @products = Current.account.products.ordered_by_name
  end

  def create
    @product = Current.account.products.build(product_params)
    @product.save!
  end

  def update
    @product.update!(product_params)
  end

  def destroy
    @product.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_product
    @product = Current.account.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name)
  end
end
