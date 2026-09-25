# Importacao de tickets de outro sistema via CSV - Configuracoes > Tickets >
# Importar. Ver Tickets::ImportService pro mapeamento completo de colunas.
class Api::V1::Accounts::TicketImportsController < Api::V1::Accounts::BaseController
  before_action -> { authorize(Current.account, :update?) }

  def create
    return render_missing_file if params[:file].blank?

    result = Tickets::ImportService.new(account: Current.account, csv_content: read_csv_content).perform
    render json: {
      created: result.created,
      skipped: result.skipped,
      errors: result.errors,
      warnings: result.warnings
    }
  rescue CSV::MalformedCSVError => e
    render json: { error: "Arquivo CSV inválido: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def render_missing_file
    render json: { error: 'Nenhum arquivo enviado' }, status: :unprocessable_entity
  end

  # Planilha exportada de outro sistema no Windows quase sempre vem em
  # Windows-1252/ISO-8859-1, nao UTF-8 - sem essa conversao, qualquer
  # acentuacao vira lixo (ou derruba o parser do CSV).
  def read_csv_content
    raw = params[:file].read
    return raw if raw.dup.force_encoding('UTF-8').valid_encoding?

    raw.force_encoding('Windows-1252').encode('UTF-8')
  end
end
