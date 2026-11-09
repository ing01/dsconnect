# Os usuarios da conta da chave, para o sistema externo descobrir o `assignee_id`
# que pode usar em POST/PATCH /tickets. So' da conta da chave: um id de outra
# conta e' 404, igual a qualquer outro recurso desta API.
#
# `?team_id=` devolve so' os membros daquela Mesa - o `assignee_id` de um ticket
# precisa ser membro da Mesa dele (ver Tickets::IntegrationWriter).
class Api::V1::Integrations::UsersController < Api::V1::Integrations::BaseController
  def index
    @users = users_scope.order(:name)
    @users = current_account.teams.find(params[:team_id]).members.order(:name) if params[:team_id].present?
    @roles = roles
  end

  def show
    @user = current_account.users.find(params[:id])
    @roles = roles
  end

  private

  def users_scope
    current_account.users
  end

  # { user_id => 'administrator' | 'agent' } - o papel e' da CONTA, entao vem do
  # vinculo (account_users), nao do usuario.
  def roles
    current_account.account_users.pluck(:user_id, :role).to_h
  end
end
