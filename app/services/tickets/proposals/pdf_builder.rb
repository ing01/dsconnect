require 'prawn'
require 'prawn/table'

# O PDF da proposta comercial, no modelo da Duesoft: cabecalho com a logo e os
# dados da empresa, PROPOSTA, RESUMO, REQUISITOS (itens e TOTAL), condicoes,
# local e data, e RESPONSAVEIS.
#
# Toda a informacao sai da propria proposta (inclusive os dados da empresa
# cliente, que foram gravados nela): reabrir o PDF meses depois mostra o que o
# cliente viu.
class Tickets::Proposals::PdfBuilder
  pattr_initialize [:proposal!]

  LOGO_PATH = Rails.public_path.join('brand-assets/duesoft_logo.png').freeze
  BRAND_COLOR = '1E73BE'.freeze
  BAR_COLOR = '1F2A37'.freeze
  MUTED_COLOR = '6B7280'.freeze
  BORDER_COLOR = 'D5DAE1'.freeze
  HEADER_FILL = 'F1F4F8'.freeze
  MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  COMPANY_NAME = 'Duesoft Sistemas para Computadores Ltda – ME'.freeze
  COMPANY_LINES = [
    'Avenida Getúlio Vargas, 163, Bosque - CEP 19010-170 - Presidente Prudente-SP',
    'Telefone: (18) 3916-7600 - www.duesoft.com.br - Email: contato@duesoft.com.br',
    'CNPJ: 09.531.276/0001-70'
  ].freeze

  # As fontes embutidas do PDF cobrem apenas Windows-1252: a acentuacao
  # portuguesa sai correta, mas aspas tipograficas, travessao e emoji derrubariam
  # o documento com IncompatibleStringEncoding. Estes caracteres ganham um
  # equivalente simples; o que sobrar sem correspondencia e descartado.
  SUBSTITUTIONS = {
    '‘' => "'", '’' => "'", '“' => '"', '”' => '"',
    '–' => '-', '—' => '-', '…' => '...'
  }.freeze

  def render
    document = Prawn::Document.new(page_size: 'A4', margin: [36, 40, 44, 40], info: { Title: "Proposta ##{ticket.display_id}" })
    write_header(document)
    write_proposal_block(document)
    write_summary(document)
    write_requirements(document)
    write_conditions(document)
    write_place_and_date(document)
    write_responsibles(document)
    write_page_numbers(document)
    document.render
  end

  private

  def ticket
    proposal.ticket
  end

  def write_header(document)
    top = document.cursor
    logo_size = 62
    document.image LOGO_PATH.to_s, at: [document.bounds.width - logo_size, top], height: logo_size

    document.bounding_box([0, top], width: document.bounds.width - logo_size - 16) do
      document.fill_color BRAND_COLOR
      document.text 'COMERCIAL', size: 9, style: :bold
      document.fill_color BAR_COLOR
      document.text 'Proposta de Customização de Software', size: 17, style: :bold
      document.move_down 3
      document.text printable(COMPANY_NAME), size: 9, style: :bold
      document.fill_color MUTED_COLOR
      COMPANY_LINES.each { |line| document.text printable(line), size: 7.5, leading: 1 }
      document.fill_color '000000'
    end

    document.move_cursor_to [document.cursor, top - logo_size - 10].min
    document.stroke_color BRAND_COLOR
    document.line_width 1.2
    document.stroke_horizontal_rule
    document.line_width 1
    document.move_down 14
  end

  def write_proposal_block(document)
    section_bar(document, 'PROPOSTA')
    width = document.bounds.width
    labels = [['N°', 70], ['CLIENTE', width - 70 - 130], ['CPF/CNPJ', 130]]
    values = [proposal_number, proposal.company_name, formatted_cnpj]

    cells = lambda do |row|
      labels.each_with_index.map do |(label, _), index|
        row == :label ? label_cell(label, index) : value_cell(values[index], index)
      end
    end

    document.table([cells.call(:label), cells.call(:value)], column_widths: labels.map(&:last),
                                                              cell_style: { size: 9, padding: [4, 8], border_color: BORDER_COLOR, border_width: 0.5 })
    document.move_down 10
  end

  def write_summary(document)
    section_bar(document, 'RESUMO')
    document.table([[printable(proposal.summary)]], width: document.bounds.width,
                                                    cell_style: { size: 9.5, padding: [7, 8], border_color: BORDER_COLOR, border_width: 0.5 })
    document.move_down 10
  end

  def write_requirements(document)
    section_bar(document, 'REQUISITOS')
    width = document.bounds.width
    document.table(requirement_rows, header: true, column_widths: [44, width - 44 - 104, 104],
                                     cell_style: { size: 9, padding: [7, 8], border_color: BORDER_COLOR, border_width: 0.5 }) do |table|
      table.row(0).background_color = HEADER_FILL
      table.row(0).font_style = :bold
      table.row(0).size = 7.5
      table.row(0).text_color = MUTED_COLOR
      table.row(-1).background_color = HEADER_FILL
    end
    document.move_down 14
  end

  def requirement_rows
    header = [{ content: 'ITEM', align: :center }, 'DESCRIÇÃO', { content: 'VALOR', align: :right }]
    items = proposal.items.each_with_index.map do |item, index|
      [{ content: (index + 1).to_s, align: :center, valign: :center },
       { content: item_markup(item), inline_format: true, leading: 2 },
       { content: currency(item['amount'].to_d), align: :right, valign: :center }]
    end
    total = [{ content: 'TOTAL:', colspan: 2, align: :right, font_style: :bold, size: 10 },
             { content: currency(proposal.amount), align: :right, font_style: :bold, size: 10 }]

    [header, *items, total]
  end

  # O titulo em negrito e, abaixo, a descricao: cada linha comecada por "-", "*"
  # ou "•" vira um marcador.
  def item_markup(item)
    markup = "<b>#{escape_markup(printable(item['title']))}</b>"
    return markup if item['description'].blank?

    "#{markup}\n\n#{escape_markup(bulleted(printable(item['description'])))}"
  end

  def bulleted(text)
    text.lines.map { |line| line.sub(/\A\s*[-*•]\s+/, '• ') }.join
  end

  def write_conditions(document)
    field(document, 'CONDIÇÕES DE PAGAMENTO', proposal.payment_terms.upcase)
    field(document, 'PRAZO PARA ENTREGA', pluralize_days(proposal.deadline_days))
    field(document, 'VALIDADE DA PROPOSTA', "#{pluralize_days(proposal.validity_days)} (ATÉ #{short_date(proposal.valid_until)})")
    document.move_down 8
  end

  def write_place_and_date(document)
    document.text printable("#{proposal.location}, #{long_date(proposal.proposal_date)}").upcase, size: 10
    document.move_down 14
  end

  def write_responsibles(document)
    # A barra e os dois campos nunca ficam divididos entre paginas.
    document.start_new_page if document.cursor < 140
    section_bar(document, 'RESPONSÁVEIS')
    document.move_down 8

    gap = 40
    width = (document.bounds.width - gap) / 2
    top = document.cursor
    [
      [0, 'DUESOFT', proposal.signer_name],
      [width + gap, 'CLIENTE', proposal.company_name]
    ].each { |x_position, label, name| signature_field(document, x_position, top, width, label, name) }
  end

  def signature_field(document, x_position, top, width, label, name)
    document.text_box label, at: [x_position, top], width: width, size: 8, style: :bold
    line_y = top - 56
    document.stroke_color '444444'
    document.stroke_line [x_position, line_y], [x_position + width, line_y]
    document.text_box printable(name), at: [x_position, line_y - 4], width: width, size: 9
  end

  def write_page_numbers(document)
    document.number_pages('<page> / <total>', at: [document.bounds.right - 60, -26], size: 7, align: :right)
  end

  # A faixa escura que abre cada secao, como no modelo da Duesoft.
  def section_bar(document, title)
    top = document.cursor
    document.fill_color BAR_COLOR
    document.fill_rectangle [0, top], document.bounds.width, 15
    document.fill_color 'FFFFFF'
    document.text_box title, at: [8, top - 4], width: document.bounds.width - 16, size: 7.5, style: :bold
    document.fill_color '000000'
    document.move_down 15
  end

  def label_cell(label, index)
    borders = index.zero? ? %i[top left] : %i[top]
    borders += [:right] if index == 2
    { content: label, font_style: :bold, size: 7, text_color: MUTED_COLOR, borders: borders, padding: [5, 8, 0, 8] }
  end

  def value_cell(value, index)
    borders = index.zero? ? %i[bottom left] : %i[bottom]
    borders += [:right] if index == 2
    { content: printable(value), borders: borders, padding: [1, 8, 6, 8] }
  end

  def field(document, label, value)
    document.text "<b>#{label}:</b> #{escape_markup(printable(value))}", size: 10, inline_format: true, leading: 2
    document.move_down 3
  end

  def pluralize_days(days)
    "#{days} #{days == 1 ? 'DIA' : 'DIAS'}"
  end

  def proposal_number
    format('%04d/%d', proposal.id, proposal.created_at.year)
  end

  def currency(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount, unit: 'R$ ', separator: ',', delimiter: '.', format: '%u%n')
  end

  def short_date(date)
    date.strftime('%d/%m/%Y')
  end

  def long_date(date)
    "#{date.day} de #{MONTHS[date.month - 1]} de #{date.year}"
  end

  # CNPJ gravado so com digitos (ver Company#normalize_cnpj); a proposta pode
  # trazer o que o agente digitou, entao so formata quando e um CNPJ de 14 digitos.
  def formatted_cnpj
    digits = proposal.company_cnpj.to_s.gsub(/\D/, '')
    return proposal.company_cnpj.to_s unless digits.length == 14

    digits.gsub(/\A(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})\z/, '\1.\2.\3/\4-\5')
  end

  def printable(text)
    text.to_s
        .gsub(/[‘’“”–—…]/, SUBSTITUTIONS)
        .encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
        .encode('UTF-8')
  end

  # `inline_format` interpreta `<` e `&`: o que o agente digitou nao pode virar
  # marcacao.
  def escape_markup(text)
    text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end
end
