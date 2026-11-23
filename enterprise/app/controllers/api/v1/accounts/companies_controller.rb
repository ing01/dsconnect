class Api::V1::Accounts::CompaniesController < Api::V1::Accounts::EnterpriseAccountsController
  include Sift
  sort_on :name, type: :string
  sort_on :domain, type: :string
  sort_on :created_at, type: :datetime
  sort_on :last_activity_at, internal_name: :order_on_last_activity_at, type: :scope, scope_params: [:direction]
  sort_on :contacts_count, internal_name: :order_on_contacts_count, type: :scope, scope_params: [:direction]

  RESULTS_PER_PAGE = 25
  BILLING_ATTRS = %i[billing_type billing_amount implementation_fee contract_id system_started_on].freeze

  before_action :ensure_companies_enabled!
  before_action :check_authorization
  before_action :set_current_page, only: [:index, :search]
  before_action :fetch_company, only: [:show, :update, :destroy, :avatar, :destroy_custom_attributes]
  before_action :set_bulk_changes, only: [:bulk_update]

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

  # Gestao de clientes: aplica as mesmas mudancas a varias Empresas de uma vez.
  # Roda em segundo plano (`Companies::BulkUpdateJob`): salvar milhares de
  # Empresas dentro da requisicao estourava o tempo e derrubava o pedido pela
  # metade. Aqui so se confere o pedido e se enfileira.
  def bulk_update
    company_ids = bulk_target_companies.pluck(:id)
    service = Companies::BulkUpdateService.new(account: Current.account, companies: Company.none, changes: @bulk_changes)
    return render json: { error: service.error }, status: :unprocessable_entity if service.error

    return render json: { queued: 0 }, status: :accepted if company_ids.empty?

    record = CompanyBulkUpdate.create!(
      account: Current.account, user: Current.user, total: company_ids.size,
      summary: Companies::BulkUpdateSummary.new(account: Current.account, changes: @bulk_changes).lines
    )
    Companies::BulkUpdateJob.perform_later(
      account_id: Current.account.id, company_ids: company_ids, changes: @bulk_changes.to_h, bulk_update_id: record.id
    )
    render json: { queued: company_ids.size, id: record.id }, status: :accepted
  end

  # O "log da alteracao" da Gestao de clientes: as ultimas alteracoes em massa,
  # com andamento e os clientes que nao puderam ser alterados.
  def bulk_updates
    records = CompanyBulkUpdate.where(account_id: Current.account.id).includes(:user).recent.limit(10)
    render json: { payload: records.map(&:as_log) }
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
    @resolved_companies ||= filter_by_status(
      filter_by_specialist(
        filter_by_company_sub_niche(
          filter_by_company_niche(
            filter_by_classification_level(
              Current.account.companies.includes(:system_modules, :company_category, :company_niche, :company_sub_niche, :specialist)
            )
          )
        )
      )
    )
  end

  # Empresas que a edicao em massa vai alterar: as marcadas na lista (`ids`) ou,
  # com `select_all`, todas as que o filtro/busca atual encontra - mesmo as de
  # outras paginas.
  def bulk_target_companies
    scope = resolved_companies
    scope = scope.search_by_name_or_domain(params[:q]) if params[:q].present?
    return scope if select_all?

    scope.where(id: Array(params[:ids]))
  end

  def select_all?
    ActiveModel::Type::Boolean.new.cast(params[:select_all])
  end

  def set_bulk_changes
    @bulk_changes = params.fetch(:changes, {}).permit(
      :company_niche_id, :company_sub_niche_id, :specialist_id, :classification_level, :status,
      :billing_type, :modules_mode, system_module_ids: []
    )
    return render_bulk_error('no_changes', :unprocessable_entity) if @bulk_changes.to_h.empty?
    return render_bulk_error('no_targets', :unprocessable_entity) unless select_all? || params[:ids].present?
    return render_bulk_error('billing_forbidden', :forbidden) if @bulk_changes.key?(:billing_type) && !can_manage_billing?

    nil
  end

  def render_bulk_error(code, status)
    render json: { error: I18n.t("errors.companies.bulk_update.#{code}") }, status: status
  end

  def filter_by_company_sub_niche(companies)
    return companies if params[:company_sub_niche_id].blank?

    companies.where(company_sub_niche_id: params[:company_sub_niche_id])
  end

  def filter_by_status(companies)
    return companies if params[:status].blank?

    companies.where(status: params[:status])
  end

  # Filtro pelo Nivel (classificacao manual, 1 a 5) - pedido da Ingrid, 2026-11-09.
  # Composto com a busca por nome/dominio: entra antes de `search_by_name_or_domain`
  # em `search`, ja que os dois passam por este mesmo metodo memoizado.
  def filter_by_classification_level(companies)
    return companies if params[:classification_level].blank?

    companies.where(classification_level: params[:classification_level])
  end

  def filter_by_company_niche(companies)
    return companies if params[:company_niche_id].blank?

    companies.where(company_niche_id: params[:company_niche_id])
  end

  def filter_by_specialist(companies)
    return companies if params[:specialist_id].blank?

    companies.where(specialist_id: params[:specialist_id])
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

  # `codigo` fica de fora de proposito - so pode ser definido pela importacao
  # de Codigo/CNPJ (`CompanyPriorityImportJob`), nunca editado a mao pelo
  # cadastro normal da empresa (pedido da Ingrid).
  # `classification_level` (o Nivel) ENTRA aqui: e' um campo manual (pedido da
  # Ingrid, 2026-11-09), tambem editavel pela importacao por planilha
  # (`CompanyClassificationImportJob`).
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
      :company_niche_id,
      :company_sub_niche_id,
      :specialist_id,
      :classification_level,
      :status,
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
    merged_params = company_params.except(:custom_attributes).merge(custom_attributes: company_custom_attributes)
    strip_system_started_on_if_has_projects(merged_params)
  end

  # "Data de inicio do uso do sistema" so e' editavel a mao quando a Empresa
  # nao tem nenhum Projeto - com Projeto, ela vem de la sozinha
  # (`Project#sync_system_started_on_to_company`). Reforcado aqui (nao so
  # desabilitando o campo no frontend) pra uma request manual nao conseguir
  # burlar a regra.
  def strip_system_started_on_if_has_projects(company_attrs)
    return company_attrs unless company_attrs.key?(:system_started_on)
    return company_attrs unless @company.projects.exists?

    company_attrs.except(:system_started_on)
  end

  def custom_attributes_to_destroy
    custom_attributes = params.permit(custom_attributes: [])[:custom_attributes]
    return custom_attributes if custom_attributes.present? || params[:custom_attributes].is_a?(Array)

    render json: { error: 'custom_attributes must be an array' }, status: :unprocessable_entity
  end
end
