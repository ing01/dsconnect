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
  #
  # `params[:file].read` sempre chega como ASCII-8BIT (binario), nunca UTF-8 -
  # so testar `valid_encoding?` numa copia NAO muda a tag de encoding do
  # `raw` de verdade. Sem aplicar `force_encoding('UTF-8')` no proprio `raw`
  # no caminho feliz, ele seguia com bytes UTF-8 validos mas marcado como
  # ASCII-8BIT, e qualquer comparacao/concatenacao com uma string UTF-8 (ex:
  # mensagens de erro do servico) derrubava com "incompatible character
  # encodings: BINARY (ASCII-8BIT) and UTF-8".
  def read_csv_content
    raw = params[:file].read
    content = if raw.dup.force_encoding('UTF-8').valid_encoding?
                raw.force_encoding('UTF-8')
              else
                raw.force_encoding('Windows-1252').encode('UTF-8')
              end
    # O Excel costuma gravar "CSV UTF-8" com um BOM na frente - sem tirar
    # ele, o nome da PRIMEIRA coluna do cabecalho vem com um caractere
    # invisivel colado, e nunca bate com HEADER_ALIASES.
    content.delete_prefix("﻿")
  end
end
