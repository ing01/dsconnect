class Api::V1::Accounts::Crm::GeneratedContractsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @contracts = Current.account.crm_generated_contracts
                        .includes(:template, :client, pdf_attachment: :blob, revisions: { pdf_attachment: :blob })
                        .order(created_at: :desc)
    @contracts = @contracts.where(crm_client_id: params[:crm_client_id]) if params[:crm_client_id].present?
  end

  def create
    template = Current.account.crm_contract_templates.find(params[:crm_contract_template_id])
    client = Current.account.crm_clients.find(params[:crm_client_id])
    sale = params[:crm_sale_id].present? ? Current.account.crm_sales.find(params[:crm_sale_id]) : nil

    # `data` tem uma chave por token do modelo escolhido - sao dinamicas
    # (vem de `extract_tokens!`), entao nao da pra usar strong params normal
    # aqui; e so texto livre usado para substituir `[[token]]` no documento,
    # nunca atribuido direto a um model.
    raw_data = params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : (params[:data] || {})

    @contract = Crm::Contracts::GenerationService.new(
      template: template, client: client, sale: sale, data: raw_data
    ).perform
  rescue Crm::Contracts::GenerationService::ConversionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def check_authorization
    authorize ::Crm::GeneratedContract
  end
end
