require 'caxlsx'

# A planilha do relatorio "Chat detalhado": a aba "Chat Detalhado" (uma linha por chat,
# 22 colunas) e a aba "Resumo" (os 8 indicadores do periodo).
class ChatDetailReport::XlsxBuilder
  COLUMNS = ChatDetailReport::Builder::COLUMNS
  SUMMARY_COLUMNS = ChatDetailReport::Builder::SUMMARY_COLUMNS

  pattr_initialize [:builder!]

  def render
    package = Axlsx::Package.new
    workbook = package.workbook
    header = workbook.styles.add_style(b: true, bg_color: 'EEEEEE', border: { style: :thin, color: 'CCCCCC' })
    summary = detail_sheet(workbook, header)
    summary_sheet(workbook, header, summary)

    package.to_stream.read
  end

  private

  # Escreve as linhas e, na mesma passada, soma o resumo.
  def detail_sheet(workbook, header)
    summary = ChatDetailReport::SummaryAccumulator.new
    keys = COLUMNS.map(&:first)
    workbook.add_worksheet(name: 'Chat Detalhado') do |sheet|
      sheet.add_row(ChatDetailReport::Builder.headers, style: header)
      builder.each_entry do |entry|
        summary.add(entry)
        sheet.add_row(entry.row.values_at(*keys))
      end
      sheet.column_widths(*widths)
    end
    summary
  end

  def summary_sheet(workbook, header, summary)
    workbook.add_worksheet(name: 'Resumo') do |sheet|
      sheet.add_row(SUMMARY_COLUMNS.map(&:last), style: header)
      sheet.add_row(summary.to_h.values_at(*SUMMARY_COLUMNS.map(&:first)))
      sheet.column_widths(*Array.new(SUMMARY_COLUMNS.size, 28))
    end
  end

  def widths
    COLUMNS.map do |key, _label|
      case key
      when :id then 12
      when :client, :contact, :assignee then 30
      when :assumed_at then 26
      else 20
      end
    end
  end
end
