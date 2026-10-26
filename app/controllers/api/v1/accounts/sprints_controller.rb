class Api::V1::Accounts::SprintsController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :fetch_sprint, only: [:update, :activate, :conclude]
  before_action :build_sprint, only: [:create]
  before_action :check_authorization

  # Sprints concluidos ficam fora: o Backlog so' precisa do que ainda esta'
  # em jogo (futuro ou em andamento). Historico de sprints passados e' tela
  # da Fase 4 (totais), nao desta lista.
  def index
    @sprints = @team.sprints.where.not(status: :completed).ordered
  end

  def create
    @sprint.save!
  end

  def update
    @sprint.update!(sprint_params)
  end

  # Qual Sprint a tela de Sprint ativo abre por padrao - nao conclui nada,
  # so' troca a escolha (e desativa o anterior da mesma Mesa, se houver).
  def activate
    @sprint.activate!
  end

  # Reencaminha pro proximo Sprint o que ainda nao chegou no Estagio final da
  # Mesa; o resto fica registrado neste Sprint como o que foi entregue nele.
  def conclude
    @sprint.conclude!
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def fetch_sprint
    @sprint = @team.sprints.find(params[:id])
  end

  def build_sprint
    @sprint = @team.sprints.build(sprint_params.merge(account: Current.account))
  end

  # `status` de fora de proposito: marcar "completed" por aqui pularia o
  # reencaminhamento de tickets que `Sprint#conclude!` (Fase 3) vai fazer -
  # um Sprint "concluido" sem isso sairia da lista do Backlog (`index` acima)
  # enquanto os tickets dele continuariam presos a ele, invisiveis. Ativar/
  # concluir um Sprint ganha acao propria quando essa fase chegar.
  def sprint_params
    params.require(:sprint).permit(:name, :starts_on, :ends_on)
  end

  # SprintPolicy decide por Mesa (membro ou admin), entao precisa da instancia
  # carregada/montada - e nao so' da classe `Sprint` que o `check_authorization`
  # generico usaria.
  def check_authorization(model = nil)
    super(model || @sprint || Sprint)
  end
end
