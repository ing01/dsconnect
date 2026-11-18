require 'caxlsx'

# A planilha da Busca detalhada: a versao COMPLETA, com todos os dados do ticket
# (ver Tickets::Export::FullSheet). Campo nao preenchido sai vazio.
#
# Escreve linha a linha a partir do ExportService, que percorre o resultado em
# lotes - a planilha nunca depende de ter todos os tickets em memoria de uma vez.
class Tickets::Export::XlsxBuilder
  pattr_initialize [:export!]

  # Colunas de texto longo: largas, para o conteudo aparecer sem abrir a celula.
  LONG_TEXT = ['Descrição', 'Observação', 'Resolução', 'Motivo do impedimento', 'Motivo do cancelamento',
               'Observações do desenvolvedor', 'Observações sobre o teste', 'Documentação', 'Instruções', 'Análise',
               'Outros campos personalizados', 'Anexos', 'Comunicações com o cliente', 'Comentários internos',
               'Apontamentos', 'Itens do checklist', 'Compromissos', 'Histórico'].freeze

  def render
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: 'Tickets') do |sheet|
      sheet.add_row(export.full_headers, style: header_style(workbook))
      export.each_full_row { |row| sheet.add_row(row) }
      sheet.column_widths(*widths)
      # Cabecalho fixo e filtro: com mais de cem colunas, sem isto a planilha nao se le.
      freeze_header(sheet)
      sheet.auto_filter = "A1:#{Axlsx.col_ref(export.full_headers.size - 1)}1"
    end

    package.to_stream.read
  end

  private

  def freeze_header(sheet)
    sheet.sheet_view.pane do |pane|
      pane.state = :frozen
      pane.y_split = 1
      pane.top_left_cell = 'A2'
      pane.active_pane = :bottom_left
    end
  end

  def header_style(workbook)
    workbook.styles.add_style(
      b: true, bg_color: 'EEEEEE', border: { style: :thin, color: 'CCCCCC' }
    )
  end

  def widths
    export.full_headers.map do |label|
      case label
      when *LONG_TEXT then 60
      when 'Título' then 45
      when /A(Data|.* emz|.*prazo)/ then 18
      else 22
      end
    end
  end
end
