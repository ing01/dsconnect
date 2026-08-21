class Api::V1::Accounts::SystemModulesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :check_authorization

  def index
    @system_modules = Current.account.system_modules.ordered_by_name
  end

  def create
    @system_module = Current.account.system_modules.build(system_module_params)
    @system_module.save!
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def system_module_params
    params.require(:system_module).permit(:name)
  end
end
