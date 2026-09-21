class Api::V1::Accounts::CompaniesController < Api::V1::Accounts::EnterpriseAccountsController
  include Sift
  sort_on :name, type: :string
  sort_on :domain, type: :string
  sort_on :created_at, type: :datetime
  sort_on :last_activity_at, internal_name: :order_on_last_activity_at, type: :scope, scope_params: [:direction]
  sort_on :contacts_count, internal_name: :order_on_contacts_count, type: :scope, scope_params: [:direction]

  RESULTS_PER_PAGE = 25
  BILLING_ATTRS = %i[billing_type billing_amount implementation_fee license_expires_on system_started_on].freeze

  before_action :ensure_companies_enabled!
  before_action :check_authorization
  before_action :set_current_page, only: [:index, :search]
  before_action :fetch_company, only: [:show, :update, :destroy, :avatar, :destroy_custom_attributes]

  def index
    @companies = fetch_companies(resolved_companies)
    @companies_count = @companies.total_count
  end

  def search
    if params[:q].blank?
      return render json: { error: I18n.t('errors.companies.search.query_missing') },
                    status: :unprocessable_entity
    end

    companies = resolved_companies.search_by_name_or_domain(params[:q])
    @companies = fetch_companies(companies)
    @companies_count = @companies.total_count
  end

  def show; end

  def cnpj_lookup
    result = Companies::CnpjLookupService.new(params[:cnpj]).perform
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error].present?

    render json: result[:data]
  end

  # Roda em background (pode levar um tempo com muitas Empresas) - so precisa
  # ser chamado depois de mudar os limiares de prioridade em Configuracoes,
  # ja que a recomputacao normal so acontece quando cada Empresa e salva.
  def recalculate_priorities
    Companies::RecalculatePrioritiesJob.perform_later(account_id: Current.account.id)
    head :accepted
  end

  def create
    @company = Current.account.companies.build(company_params)
    @company.save!
  end

  def update
    @company.update!(company_update_params)
  end

  def destroy_custom_attributes
    custom_attributes = custom_attributes_to_destroy
    return if performed?

    @company.custom_attributes = @company.custom_attributes.excluding(*custom_attributes)
    @company.save!
  end

  def destroy
    Companies::DeleteJob.perform_later(company_id: @company.id)
    head :ok
  end

  def avatar
    @company.avatar.purge if @company.avatar.attached?
  end

  private

  def resolved_companies
    @resolved_companies ||= Current.account.companies.includes(:system_modules, :company_category)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def fetch_companies(companies)
    filtrate(companies)
      .page(@current_page)
      .per(RESULTS_PER_PAGE)
  end

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_company
    @company = Current.account.companies.find(params[:id])
  end

  # `client_level` (a Prioridade) nao entra aqui de proposito - e' sempre
  # recalculada pelo model a partir de `billing_amount` (ver
  # Company#compute_client_level), nunca definida manualmente pela request.
  def company_params
    params.require(:company).permit(
      :name,
      :domain,
      :description,
      :avatar,
      :legal_name,
      :cnpj,
      :ie,
      :im,
      :address_zip_code,
      :address_street,
      :address_number,
      :address_complement,
      :address_neighborhood,
      :address_city,
      :address_state,
      :campaign_opt_in,
      :blocked,
      :company_category_id,
      *allowed_billing_attrs,
      additional_attributes: {},
      custom_attributes: {},
      system_module_ids: []
    )
  end

  # "Contrato e cobrança" is administrator-only (same bar as
  # `client_credentials_manage` for the Credenciais tab): stripping the keys
  # here - rather than only hiding the tab in the frontend - means a manual
  # request can't change billing without the permission either.
  def allowed_billing_attrs
    return BILLING_ATTRS if can_manage_billing?

    []
  end

  def can_manage_billing?
    Current.account_user&.administrator? || Current.account_user&.permissions&.include?('client_billing_manage')
  end

  def company_custom_attributes
    custom_attributes = company_params[:custom_attributes]
    return @company.custom_attributes.merge(custom_attributes.to_h) if custom_attributes.present?

    @company.custom_attributes
  end

  def company_update_params
    company_params.except(:custom_attributes).merge(custom_attributes: company_custom_attributes)
  end

  def custom_attributes_to_destroy
    custom_attributes = params.permit(custom_attributes: [])[:custom_attributes]
    return custom_attributes if custom_attributes.present? || params[:custom_attributes].is_a?(Array)

    render json: { error: 'custom_attributes must be an array' }, status: :unprocessable_entity
  end
end
