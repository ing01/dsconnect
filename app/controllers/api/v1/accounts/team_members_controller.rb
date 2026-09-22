class Api::V1::Accounts::TeamMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :check_authorization
  before_action :validate_member_id_params, only: [:create, :update, :destroy]

  def index
    @team_members = @team.team_members.map(&:user)
    # Em que niveis cada um pode atuar, por id. Fora do agente porque o nivel e
    # da participacao na Mesa, e nao da pessoa: a mesma pessoa pode ser Nivel 1
    # numa Mesa e Nivel 2 em outra.
    @levels_by_user = @team.team_members.pluck(:user_id, :levels).to_h
  end

  def create
    ActiveRecord::Base.transaction do
      @team_members = @team.add_members(members_to_be_added_ids)
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @team.add_members(members_to_be_added_ids)
      @team.remove_members(members_to_be_removed_ids)
    end
    @team_members = @team.members
    render action: 'create'
  end

  def destroy
    ActiveRecord::Base.transaction do
      @team.remove_members(params[:user_ids])
    end
    head :ok
  end

  # Define em quais niveis cada membro pode atuar, no formato
  # `{ levels: { "<user_id>": [1, 2] } }`.
  #
  # So mexe em quem foi enviado: um membro ausente do payload fica como estava,
  # entao a tela pode salvar uma linha sem reenviar a Mesa inteira.
  def update_levels
    ActiveRecord::Base.transaction do
      levels_param.each do |user_id, levels|
        member = @team.team_members.find_by(user_id: user_id)
        member&.update!(levels: sanitize_levels(levels))
      end
    end
    @team_members = @team.members
    render action: 'create'
  end

  private

  def members_to_be_added_ids
    params[:user_ids] - current_members_ids
  end

  def members_to_be_removed_ids
    current_members_ids - params[:user_ids]
  end

  def current_members_ids
    @current_members_ids ||= @team.members.pluck(:id)
  end

  def levels_param
    params.require(:levels).permit!.to_h
  end

  # So os niveis que ESTA Mesa usa, sem repeticao: o valor vem do cliente e vai
  # para uma coluna que a consulta de permissao le direto. Uma Mesa que atende em
  # dois niveis nao guarda habilitacao de Nivel 3 - se amanha ela passar a usar
  # tres, a habilitacao e dada de novo, de proposito: ninguem herda um nivel que
  # nao existia quando foi cadastrado.
  def sanitize_levels(levels)
    niveis_da_mesa = @team.assignee_levels
    Array(levels).map(&:to_i).uniq.select { |level| niveis_da_mesa.include?(level) }
  end

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def validate_member_id_params
    invalid_ids = params[:user_ids].map(&:to_i) - @team.account.user_ids

    render json: { error: 'Invalid User IDs' }, status: :unauthorized and return if invalid_ids.present?
  end
end
