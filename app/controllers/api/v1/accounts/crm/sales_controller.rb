class Api::V1::Accounts::Crm::SalesController < Api::V1::Accounts::BaseController
  before_action :fetch_sale, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @sales = Current.account.crm_sales.includes(:client, :seller, :items).order(competencia: :desc, created_at: :desc)

    @sales = @sales.where(crm_client_id: params[:crm_client_id]) if params[:crm_client_id].present?
    @sales = @sales.where(user_id: params[:user_id]) if params[:user_id].present?
  end

  def show; end

  def create
    @sale = Current.account.crm_sales.create!(sale_params)
  end

  def update
    @sale.update!(sale_params)
    render 'show'
  end

  def destroy
    @sale.destroy!
    head :ok
  end

  private

  def fetch_sale
    @sale = Current.account.crm_sales.find(params[:id])
  end

  def check_authorization
    authorize ::Crm::Sale
  end

  def sale_params
    params.require(:crm_sale).permit(
      :crm_client_id, :user_id, :competencia, :payment_method, :installments, :channel,
      items_attributes: [:id, :product, :implementation_value, :monthly_value, :_destroy]
    )
  end
end
