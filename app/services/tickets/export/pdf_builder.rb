require 'prawn'
require 'prawn/table'

# O relatorio impresso da Busca detalhada.
#
# Paisagem de proposito: sao doze colunas, e em retrato elas ficariam estreitas
# demais para serem lidas.
class Tickets::Export::PdfBuilder
  pattr_initialize [:export!, :generated_by!, :account!]

  # Cabecalhos curtos so aqui. Na planilha eles sao por extenso; numa pagina com
  # doze colunas, "Mesa de Servico" sozinho ja empurra a largura minima da
  # tabela para alem do papel.
  HEADERS = ['No.', 'Criado', 'Titulo', 'Empresa', 'Solicitante', 'Atendente',
             'Mesa', 'Estagio', 'Status', 'Prior.', 'Categoria', 'Fechado'].freeze

  # Quanto texto cabe em cada coluna. O que passa disso e cortado, porque um
  # titulo enorme faria a tabela nao caber e o Prawn recusaria desenha-la; a
  # planilha continua com o texto inteiro, para quem precisar dele.
  LIMITS = {
    title: 46, company: 22, contact: 22, assignee: 18,
    team: 14, column: 16, category: 18
  }.freeze

  def render
    document = Prawn::Document.new(page_size: 'A4', page_layout: :landscape, margin: 24)
    write_header(document)
    write_table(document)
    write_page_numbers(document)
    document.render
  end

  private

  def write_header(document)
    document.font_size(15) { document.text 'Relatorio de Tickets', style: :bold }
    document.move_down 6

    document.font_size(8) do
      document.text printable("Gerado em #{now} por #{generated_by}")
      document.move_down 3
      # Nome de empresa ou de pessoa tambem passa pela mesma limpeza.
      export.applied_filters.each { |line| document.text printable(line) }
      document.move_down 3
      document.text "#{export.count} ticket(s) encontrado(s)"
    end

    document.move_down 8
  end

  def write_table(document)
    rows = table_rows
    return document.text('Nenhum ticket encontrado.', size: 9) if rows.size == 1

    # Sem larguras fixas: o Prawn distribui pelo conteudo, e o que ainda assim
    # nao couber encolhe em vez de estourar a pagina.
    document.table(
      rows, header: true, width: document.bounds.width,
            cell_style: { size: 6.5, padding: 3, overflow: :shrink_to_fit, min_font_size: 5 }
    ) do |table|
      table.row(0).font_style = :bold
      table.row(0).background_color = 'EEEEEE'
      table.cells.borders = [:bottom]
      table.cells.border_color = 'DDDDDD'
    end
  end

  def table_rows
    keys = column_keys
    [HEADERS] + export.each_row.map { |row| keys.map { |key| trim(row[key], LIMITS[key]) } }
  end

  # As fontes embutidas do PDF cobrem apenas Windows-1252. Acentuacao portuguesa
  # esta la e sai correta; o que nao esta - emoji, aspas tipograficas, travessao
  # - derrubaria o relatorio inteiro com IncompatibleStringEncoding. Entao esses
  # poucos caracteres viram equivalentes simples, e o que sobra e descartado.
  SUBSTITUTIONS = {
    '‘' => "'", '’' => "'", '“' => '"', '”' => '"',
    '–' => '-', '—' => '-', '…' => '...', ' ' => ' '
  }.freeze

  def printable(text)
    text
      .gsub(/[‘’“”–—… ]/) { |char| SUBSTITUTIONS[char] }
      .encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
      .encode('UTF-8')
  end

  def trim(value, limit)
    text = printable(value.to_s)
    return text if limit.blank?

    # Insere um espaco dentro de palavras longas demais para caberem sozinhas
    # numa celula - sem isso a tabela inteira deixa de caber.
    text.truncate(limit).gsub(/(\S{16})(?=\S)/) { "#{Regexp.last_match(1)} " }
  end

  def write_page_numbers(document)
    document.number_pages(
      '<page> / <total>', at: [document.bounds.right - 60, -12], size: 7
    )
  end

  def column_keys
    Tickets::ExportService::COLUMNS.pluck(:key)
  end

  def now
    Time.current
        .in_time_zone(account.reporting_timezone.presence || 'UTC')
        .strftime('%d/%m/%Y %H:%M')
  end
end
