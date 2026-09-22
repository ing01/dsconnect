class Api::V1::Accounts::ContractsController < Api::V1::Accounts::EnterpriseAccountsController
  RESULTS_PER_PAGE = 25

  before_action :ensure_companies_enabled!
  before_action :check_authorization
  before_action :set_current_page, only: [:index, :search]
  before_action :fetch_contract, only: [:show, :update, :destroy]

  def index
    @contracts = fetch_contracts(resolved_contracts)
    @contracts_count = @contracts.total_count
  end

  def search
    if params[:q].blank?
      return render json: { error: I18n.t('errors.companies.search.query_missing') },
                    status: :unprocessable_entity
    end

    contracts = resolved_contracts.search_by_participant_or_responsible(params[:q])
    @contracts = fetch_contracts(contracts)
    @contracts_count = @contracts.total_count
  end

  def show; end

  def create
    @contract = Current.account.contracts.build(contract_attrs)
    @contract.save!
    @contract.sync_companies!(company_ids)
  end

  def update
    @contract.update!(contract_attrs)
    @contract.sync_companies!(company_ids) if params[:contract].key?(:company_ids)
  end

  def destroy
    @contract.destroy!
    head :ok
  end

  private

  def resolved_contracts
    @resolved_contracts ||= Current.account.contracts.includes(:responsible_contact, :companies,
                                                                 contract_products: :product)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def fetch_contracts(contracts)
    contracts.order(created_at: :desc).page(@current_page).per(RESULTS_PER_PAGE)
  end

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_contract
    @contract = Current.account.contracts.find(params[:id])
  end

  # `company_ids` nao e' coluna do Contract (e' o inverso, `companies.contract_id`) -
  # tratado a parte em `Contract#sync_companies!` pra passar por
  # `Company#update!` (dispara `sync_billing_from_contract`), nunca um
  # `update_all` que pularia esse callback.
  def contract_params
    params.require(:contract).permit(
      :responsible_contact_id, :contract_type, :total_value_mode, :total_value,
      company_ids: [],
      contract_products_attributes: %i[id product_id unit_value licenses_qty implementation_fee _destroy]
    )
  end

  def contract_attrs
    contract_params.except(:company_ids)
  end

  def company_ids
    Array(params.dig(:contract, :company_ids)).compact_blank
  end
end
