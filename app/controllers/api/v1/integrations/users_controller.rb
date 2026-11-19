# Os usuarios da conta da chave, para o sistema externo descobrir o `assignee_id`
# que pode usar em POST/PATCH /tickets. So' da conta da chave: um id de outra
# conta e' 404, igual a qualquer outro recurso desta API.
#
# `?team_id=` devolve so' os membros daquela Mesa - o `assignee_id` de um ticket
# precisa ser membro da Mesa dele (ver Tickets::IntegrationWriter).
#
# Cada usuario traz os Nichos e Sub-nichos de empresa que atende (`niches`, `sub_niches`, listas de
# { id, name }), para casar com o `niche`/`sub_niche` de GET /companies. `?niche_id=` e
# `?sub_niche_id=` devolvem so' quem atende aquele Nicho / Sub-nicho.
class Api::V1::Integrations::UsersController < Api::V1::Integrations::BaseController
  def index
    @users = users_scope.order(:name)
    @users = current_account.teams.find(params[:team_id]).members.order(:name) if params[:team_id].present?
    @users = filter_by_niche(@users)
    @roles = roles
    load_niches(@users)
  end

  def show
    @user = current_account.users.find(params[:id])
    @roles = roles
    load_niches([@user])
  end

  private

  def filter_by_niche(scope)
    if params[:niche_id].present?
      scope = scope.where(id: UserCompanyNiche.where(account_id: current_account.id, company_niche_id: params[:niche_id]).select(:user_id))
    end
    if params[:sub_niche_id].present?
      scope = scope.where(id: UserCompanySubNiche.where(account_id: current_account.id, company_sub_niche_id: params[:sub_niche_id]).select(:user_id))
    end
    scope
  end

  # { user_id => [{ id, name }] } - em duas consultas para a lista toda, sem N+1.
  def load_niches(users)
    ids = users.map(&:id)
    @niches = UserCompanyNiche.where(account_id: current_account.id, user_id: ids).includes(:company_niche).group_by(&:user_id)
    @sub_niches = UserCompanySubNiche.where(account_id: current_account.id, user_id: ids).includes(:company_sub_niche).group_by(&:user_id)
  end

  def users_scope
    current_account.users
  end

  # { user_id => 'administrator' | 'agent' } - o papel e' da CONTA, entao vem do
  # vinculo (account_users), nao do usuario.
  def roles
    current_account.account_users.pluck(:user_id, :role).to_h
  end
end
