require 'caxlsx'

# A planilha da Busca detalhada.
#
# Escreve linha a linha a partir do ExportService, que percorre o resultado em
# lotes - a planilha nunca depende de ter todos os tickets em memoria de uma vez.
class Tickets::Export::XlsxBuilder
  pattr_initialize [:export!]

  def render
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: 'Tickets') do |sheet|
      sheet.add_row(export.headers, style: header_style(workbook))
      export.each_row { |row| sheet.add_row(row.values_at(*column_keys)) }
      sheet.column_widths(*widths)
    end

    package.to_stream.read
  end

  private

  def column_keys
    Tickets::ExportService::COLUMNS.pluck(:key)
  end

  def header_style(workbook)
    workbook.styles.add_style(
      b: true, bg_color: 'EEEEEE', border: { style: :thin, color: 'CCCCCC' }
    )
  end

  # O titulo e o campo que mais cresce; os demais cabem confortavelmente.
  def widths
    Tickets::ExportService::COLUMNS.map do |column|
      case column[:key]
      when :title then 45
      when :display_id then 10
      when :created_at, :closed_at then 18
      else 22
      end
    end
  end
end
