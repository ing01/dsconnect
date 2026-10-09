class Api::V1::Accounts::Crm::ClientsController < Api::V1::Accounts::BaseController
  before_action :fetch_client, only: [:show, :update, :destroy, :change_representative]
  before_action :check_authorization

  def index
    @clients = Current.account.crm_clients.order(:name)

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @clients = @clients.where(
        'LOWER(name) LIKE :term OR LOWER(cnpj) LIKE :term OR LOWER(contact_name) LIKE :term', term: term
      )
    end
  end

  def show; end

  def create
    @client = Current.account.crm_clients.create!(client_params)
  end

  def update
    @client.update!(client_params)
    render 'show'
  end

  def destroy
    @client.destroy!
    head :ok
  end

  # So' os dados do representante NOVO - o resto do cadastro (endereco,
  # contato etc.) nao muda aqui. Atualiza o cliente e regenera TODOS os
  # contratos ja gerados para ele, um a um: o PDF/DOCX antigo de cada um vai
  # para uma Crm::GeneratedContractRevision antes de ser sobrescrito (ver
  # Crm::Contracts::RegenerationService). Um contrato cuja conversao falhar
  # (ex.: LibreOffice fora do ar) nao impede os outros nem desfaz a troca de
  # representante em si - ela ja esta' salva quando o loop comeca.
  def change_representative
    @client.update!(representative_params)
    @results = @client.generated_contracts.map do |contract|
      Crm::Contracts::RegenerationService.new(contract: contract, reason: 'representative_change').perform
      { id: contract.id, status: 'ok' }
    rescue Crm::Contracts::GenerationService::ConversionError => e
      { id: contract.id, status: 'error', error: e.message }
    end
  end

  private

  def fetch_client
    @client = Current.account.crm_clients.find(params[:id])
  end

  def check_authorization
    authorize ::Crm::Client
  end

  def client_params
    params.require(:crm_client).permit(
      :name, :cnpj, :contact_name, :phone, :email, :notes,
      :trade_name, :state_registration, :address_street, :address_number, :address_complement,
      :address_neighborhood, :city, :state, :zip_code,
      :representative_name, :representative_cpf, :representative_birth_date, :representative_phone, :representative_mobile,
      :representative_address_street, :representative_address_number, :representative_address_complement,
      :representative_neighborhood, :representative_city, :representative_state, :representative_zip_code,
      extra_representatives: [:name, :cpf, :birth_date, :phone, :address]
    )
  end

  def representative_params
    params.require(:crm_client).permit(
      :representative_name, :representative_cpf, :representative_birth_date, :representative_phone, :representative_mobile,
      :representative_address_street, :representative_address_number, :representative_address_complement,
      :representative_neighborhood, :representative_city, :representative_state, :representative_zip_code
    )
  end
end
