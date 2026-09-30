# Os niveis de Complexidade da conta - Configuracoes > Tickets > Complexidade.
#
# Mesma forma do ServiceCatalogsController: lista da conta, com `active` e
# `position`. O que ele tem a mais e a matriz por Mesa (`team_ids`), que diz
# quais Mesas oferecem cada nivel.
class Api::V1::Accounts::TicketComplexitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket_complexity, only: [:update, :destroy]
  before_action :check_authorization

  # A lista inteira de uma vez: e pequena, e tanto a tela de configuracao quanto
  # o formulario de ticket precisam dela completa.
  #
  # Semeia os tres niveis iniciais numa conta que nunca os teve, pela mesma razao
  # que o quadro de Sugestoes semeia as colunas: a tela nao pode abrir vazia numa
  # conta que existe desde antes desta funcionalidade. Idempotente.
  def index
    Tickets::DefaultComplexitiesBuilder.new(account: Current.account).perform

    @ticket_complexities = Current.account.ticket_complexities.ordered.to_a
    # A matriz numa consulta, e nao uma por nivel.
    @team_ids_by_complexity = TicketComplexity.team_ids_by_complexity(@ticket_complexities.map(&:id))
  end

  def create
    @ticket_complexity = Current.account.ticket_complexities.create!(ticket_complexity_params)
    apply_teams(@ticket_complexity)
    render 'show'
  end

  def update
    @ticket_complexity.update!(ticket_complexity_params)
    apply_teams(@ticket_complexity)
    render 'show'
  end

  # Desligar (`active: false`) e o caminho comum: o nivel sai dos formularios e
  # continua nos tickets que o usam. Apagar existe para um nivel criado por
  # engano; os tickets que o tiverem simplesmente voltam a ficar sem
  # Complexidade (`dependent: :nullify`).
  def destroy
    @ticket_complexity.destroy!
    head :ok
  end

  private

  def fetch_ticket_complexity
    @ticket_complexity = Current.account.ticket_complexities.find(params[:id])
  end

  # Ausente o campo, a matriz fica como estava: assim uma tela que so renomeia o
  # nivel nao apaga as Mesas dele sem pedir.
  def apply_teams(complexity)
    return unless params[:ticket_complexity].key?(:team_ids)

    complexity.replace_teams!(params[:ticket_complexity][:team_ids])
  end

  def check_authorization(model = nil)
    super(model || @ticket_complexity || TicketComplexity)
  end

  def ticket_complexity_params
    params.require(:ticket_complexity).permit(:name, :active, :position, :weight)
  end
end
