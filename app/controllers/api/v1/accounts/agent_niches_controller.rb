# Os Nichos e Sub-nichos de empresa que cada agente (analista) atende - Configuracoes > Nichos por
# agente. Consulta para qualquer um da conta; alterar e' do administrador.
#
#   GET /agent_niches          -> { agents: [...], niches: [...], sub_niches: [...] }
#   PUT /agent_niches/:id      -> troca a lista do agente (`:id` e' o id do usuario), com
#                                 `niche_ids` e `sub_niche_ids`; o que nao vier fica como esta
class Api::V1::Accounts::AgentNichesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: payload
  end

  def update
    agent = Current.account.users.find(params[:id])
    ActiveRecord::Base.transaction do
      replace_niches(agent) if params.key?(:niche_ids)
      replace_sub_niches(agent) if params.key?(:sub_niche_ids)
    end
    render json: agent_json(agent, *links_for([agent.id]))
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def check_authorization(model = nil)
    super(model || :agent_niche)
  end

  def payload
    users = Current.account.users.order(:name).to_a
    niches_by_user, sub_niches_by_user = links_for(users.map(&:id))
    {
      agents: users.map { |user| agent_json(user, niches_by_user, sub_niches_by_user) },
      niches: Current.account.company_niches.ordered_by_name.map { |niche| { id: niche.id, name: niche.name } },
      sub_niches: Current.account.company_sub_niches.ordered_by_name.map { |sub| { id: sub.id, name: sub.name } }
    }
  end

  def links_for(user_ids)
    [
      UserCompanyNiche.where(account_id: Current.account.id, user_id: user_ids).group_by(&:user_id),
      UserCompanySubNiche.where(account_id: Current.account.id, user_id: user_ids).group_by(&:user_id)
    ]
  end

  def agent_json(user, niches_by_user, sub_niches_by_user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      niche_ids: Array(niches_by_user[user.id]).map(&:company_niche_id),
      sub_niche_ids: Array(sub_niches_by_user[user.id]).map(&:company_sub_niche_id)
    }
  end

  # Ids de outra conta (ou inexistentes) sao ignorados: so' valem os da conta do agente.
  def replace_niches(agent)
    ids = Current.account.company_niches.where(id: Array(params[:niche_ids])).pluck(:id)
    UserCompanyNiche.where(account_id: Current.account.id, user_id: agent.id).where.not(company_niche_id: ids).destroy_all
    existing = UserCompanyNiche.where(user_id: agent.id).pluck(:company_niche_id)
    (ids - existing).each { |id| UserCompanyNiche.create!(account: Current.account, user: agent, company_niche_id: id) }
  end

  def replace_sub_niches(agent)
    ids = Current.account.company_sub_niches.where(id: Array(params[:sub_niche_ids])).pluck(:id)
    UserCompanySubNiche.where(account_id: Current.account.id, user_id: agent.id).where.not(company_sub_niche_id: ids).destroy_all
    existing = UserCompanySubNiche.where(user_id: agent.id).pluck(:company_sub_niche_id)
    (ids - existing).each { |id| UserCompanySubNiche.create!(account: Current.account, user: agent, company_sub_niche_id: id) }
  end
end
