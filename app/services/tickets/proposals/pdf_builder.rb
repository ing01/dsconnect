require 'prawn'

# O PDF da proposta comercial, com a logo da Duesoft.
#
# Toda a informacao sai da propria proposta (inclusive os dados da empresa, que
# foram gravados nela): reabrir o PDF meses depois mostra o que o cliente viu.
class Tickets::Proposals::PdfBuilder
  pattr_initialize [:proposal!]

  LOGO_PATH = Rails.public_path.join('brand-assets/logo.png').freeze
  BRAND_COLOR = '1B5FD6'.freeze
  MUTED_COLOR = '666666'.freeze
  MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  # As fontes embutidas do PDF cobrem apenas Windows-1252: a acentuacao
  # portuguesa sai correta, mas aspas tipograficas, travessao e emoji derrubariam
  # o documento com IncompatibleStringEncoding. Estes caracteres ganham um
  # equivalente simples; o que sobrar sem correspondencia e descartado.
  SUBSTITUTIONS = {
    '‘' => "'", '’' => "'", '“' => '"', '”' => '"',
    '–' => '-', '—' => '-', '…' => '...'
  }.freeze

  def render
    document = Prawn::Document.new(page_size: 'A4', margin: 50, info: { Title: "Proposta ##{ticket.display_id}" })
    write_header(document)
    write_company(document)
    write_description(document)
    write_conditions(document)
    write_place_and_date(document)
    write_signatures(document)
    write_page_numbers(document)
    document.render
  end

  private

  def ticket
    proposal.ticket
  end

  def write_header(document)
    top = document.cursor
    document.image LOGO_PATH.to_s, at: [0, top], height: 48
    document.bounding_box([60, top], width: document.bounds.width - 60, height: 48) do
      document.fill_color BRAND_COLOR
      document.text 'PROPOSTA COMERCIAL', size: 18, style: :bold, align: :right
      document.fill_color MUTED_COLOR
      document.text printable("Ticket ##{ticket.display_id}"), size: 10, align: :right
      document.fill_color '000000'
    end
    document.move_down 10
    document.stroke_color BRAND_COLOR
    document.stroke_horizontal_rule
    document.move_down 18
  end

  def write_company(document)
    section_title(document, 'Dados da empresa')
    field(document, 'Empresa', proposal.company_name)
    field(document, 'CNPJ', formatted_cnpj) if proposal.company_cnpj.present?
    field(document, 'Endereço', proposal.company_address) if proposal.company_address.present?
    document.move_down 12
  end

  def write_description(document)
    section_title(document, 'Descrição da melhoria')
    document.text printable(proposal.description), size: 10, leading: 3
    document.move_down 14
  end

  def write_conditions(document)
    section_title(document, 'Condições da proposta')
    field(document, 'Ticket', "##{ticket.display_id} - #{ticket.title}")
    field(document, 'Valor do desenvolvimento', currency(proposal.amount))
    field(document, 'Condição de pagamento', proposal.payment_terms)
    field(document, 'Prazo', "#{proposal.deadline_days} #{proposal.deadline_days == 1 ? 'dia' : 'dias'}")
    field(document, 'Data da proposta', short_date(proposal.proposal_date))
    field(document, 'Validade da proposta', short_date(proposal.valid_until))
    document.move_down 18
  end

  def write_place_and_date(document)
    document.text printable("#{proposal.location}, #{long_date(proposal.proposal_date)}"), size: 10, align: :right
  end

  def write_signatures(document)
    # Os dois campos nunca ficam divididos entre paginas.
    document.start_new_page if document.cursor < 140
    document.move_down 60

    gap = 40
    width = (document.bounds.width - gap) / 2
    top = document.cursor
    [
      [0, 'DUESOFT SISTEMAS', proposal.signer_name.presence || 'Responsável'],
      [width + gap, proposal.company_name, 'Cliente']
    ].each { |x, name, role| signature_field(document, x, top, width, name, role) }
  end

  def signature_field(document, x_position, top, width, name, role)
    document.stroke_color '444444'
    document.stroke_line [x_position, top], [x_position + width, top]
    document.bounding_box([x_position, top - 4], width: width) do
      document.text printable(name), size: 9, style: :bold, align: :center
      document.text printable(role), size: 8, align: :center
    end
  end

  def write_page_numbers(document)
    document.number_pages('<page> / <total>', at: [document.bounds.right - 60, -20], size: 7, align: :right)
  end

  def section_title(document, text)
    document.fill_color BRAND_COLOR
    document.text text.upcase, size: 10, style: :bold
    document.fill_color '000000'
    document.move_down 5
  end

  def field(document, label, value)
    document.text "<b>#{label}:</b> #{escape_markup(printable(value))}", size: 10, inline_format: true, leading: 2
    document.move_down 3
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
    return proposal.company_cnpj unless digits.length == 14

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
