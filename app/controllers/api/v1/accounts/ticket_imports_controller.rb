# Importacao de tickets de outro sistema via CSV - Configuracoes > Tickets >
# Importar. So enfileira o trabalho de verdade (Tickets::ImportJob); a tela
# consulta `show` periodicamente pra acompanhar o progresso, ja que uma
# planilha real pode ter dezenas de milhares de linhas e nao teria como
# processar tudo dentro de uma unica requisicao web. `index` e' o log: as
# ultimas importacoes da conta, pra saber o que ja rodou sem precisar guardar
# o resultado na tela aberta no momento.
class Api::V1::Accounts::TicketImportsController < Api::V1::Accounts::BaseController
  LOG_LIMIT = 20

  before_action -> { authorize(Current.account, :update?) }
  before_action :fetch_ticket_import, only: [:show]

  def index
    ticket_imports = Current.account.ticket_imports.recent_first.limit(LOG_LIMIT).includes(:user)
    render json: ticket_imports.map(&:push_event_data)
  end

  def create
    return render_missing_file if params[:file].blank?

    ticket_import = Current.account.ticket_imports.create!(user: Current.user)
    ticket_import.file.attach(params[:file])
    Tickets::ImportJob.perform_later(ticket_import.id)

    render json: ticket_import.push_event_data, status: :created
  end

  def show
    render json: @ticket_import.push_event_data
  end

  private

  def fetch_ticket_import
    @ticket_import = Current.account.ticket_imports.find(params[:id])
  end

  def render_missing_file
    render json: { error: 'Nenhum arquivo enviado' }, status: :unprocessable_entity
  end
end
