class Api::V1::Accounts::Crm::ContractTemplatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @templates = Current.account.crm_contract_templates.order(:name)
  end

  def create
    @template = Current.account.crm_contract_templates.new(name: params[:name])
    @template.file.attach(params[:file])
    @template.save!
    @template.extract_tokens!
  end

  def destroy
    template = Current.account.crm_contract_templates.find(params[:id])
    template.destroy!
    head :ok
  end

  private

  def check_authorization
    authorize ::Crm::ContractTemplate
  end
end
