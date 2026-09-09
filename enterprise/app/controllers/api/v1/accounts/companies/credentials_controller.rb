class Api::V1::Accounts::Companies::CredentialsController < Api::V1::Accounts::Companies::BaseController
  before_action -> { check_authorization(CompanyCredential) }
  before_action :fetch_credential, only: [:show, :update, :destroy]

  def index
    @credentials = @company.company_credentials.order(:label)
  end

  def show; end

  def create
    @credential = @company.company_credentials.build(credential_params)
    @credential.account = Current.account
    @credential.created_by = Current.user
    @credential.updated_by = Current.user
    @credential.save!
  end

  def update
    @credential.updated_by = Current.user
    @credential.update!(credential_params)
  end

  def destroy
    @credential.destroy!
    head :ok
  end

  private

  def fetch_credential
    @credential = @company.company_credentials.find(params[:id])
  end

  def credential_params
    params.require(:company_credential).permit(
      :label, :db_type, :db_name, :db_host, :db_port, :db_username, :db_password,
      :anydesk_id, :anydesk_password, :remote_access_type, :rdp_address, :rdp_username, :rdp_password, :notes
    )
  end
end
