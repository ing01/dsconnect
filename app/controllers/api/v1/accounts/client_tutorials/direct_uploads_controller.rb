# Cria o blob do VIDEO de um tutorial da Area do Cliente, que o navegador envia
# direto ao storage - o arquivo pesa dezenas de MB e nao deve passar pela
# aplicacao. So' administradores da conta (mesma regra de editar o tutorial).
class Api::V1::Accounts::ClientTutorials::DirectUploadsController < ActiveStorage::DirectUploadsController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include EnsureCurrentAccountHelper

  # Nao herda do ApplicationController (que dispensa o CSRF): a autenticacao e' por
  # header de token, nao por cookie de sessao.
  skip_before_action :verify_authenticity_token

  around_action :handle_with_exception
  before_action :authenticate_user!
  before_action :current_account
  before_action :ensure_administrator

  private

  def ensure_administrator
    return if @current_account&.account_users&.find_by(user_id: current_user.id)&.administrator?

    head :forbidden
  end
end
