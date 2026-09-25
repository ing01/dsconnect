require 'csv'

# Importa tickets de uma planilha (CSV) exportada de outro sistema -
# Configuracoes > Tickets > Importar. Cada linha e processada isolada: uma
# falha numa linha (ex: Mesa/Estagio inexistente) so descarta aquela linha,
# nunca o lote inteiro.
#
# Cabecalho esperado (nomes exatos, sem acento tambem funciona - ver
# HEADER_ALIASES): Numero, Cliente, Titulo, Descricao, Status, Estagio,
# Contato, Time, Prioridade, Catalogo de Servicos, Area do Catalogo de
# Servicos, Item, Ticket pai, Criado por, Criado em, Categoria, Data.
#
# Duas passadas: a primeira cria os tickets (sem "Ticket pai" ainda), a
# segunda liga o "Ticket pai" usando o "Numero" original que cada ticket
# guarda em `custom_attributes['imported_ticket_number']` - funciona tanto
# para um pai importado no mesmo arquivo quanto num arquivo anterior.
class Tickets::ImportService
  Result = Struct.new(:created, :skipped, :errors, :warnings, keyword_init: true)

  STATUS_ALIASES = {
    'aberto' => 'open', 'open' => 'open',
    'resolvido' => 'resolved', 'resolved' => 'resolved',
    'fechado' => 'closed', 'concluido' => 'closed', 'concluído' => 'closed', 'closed' => 'closed',
    'cancelado' => 'cancelled', 'cancelled' => 'cancelled', 'canceled' => 'cancelled'
  }.freeze

  PRIORITY_ALIASES = {
    'baixa' => 'low', 'low' => 'low',
    'media' => 'medium', 'média' => 'medium', 'medium' => 'medium',
    'alta' => 'high', 'high' => 'high',
    'urgente' => 'urgent', 'urgent' => 'urgent'
  }.freeze

  # Da esquerda (nome que a planilha usa) pro nome de campo interno.
  HEADER_ALIASES = {
    'número' => 'numero', 'numero' => 'numero',
    'cliente' => 'cliente',
    'título' => 'titulo', 'titulo' => 'titulo',
    'descrição' => 'descricao', 'descricao' => 'descricao',
    'status' => 'status',
    'estágio' => 'estagio', 'estagio' => 'estagio',
    'contato' => 'contato',
    'time' => 'time',
    'prioridade' => 'prioridade',
    'catálogo de serviços' => 'catalogo', 'catalogo de servicos' => 'catalogo',
    'área do catálogo de serviços' => 'area', 'area do catalogo de servicos' => 'area',
    'item' => 'item',
    'ticket pai' => 'ticket_pai',
    'criado por' => 'criado_por',
    'criado em' => 'criado_em',
    'categoria' => 'categoria',
    'data' => 'data'
  }.freeze

  pattr_initialize [:account!, :csv_content!]

  def perform
    rows = parse_csv
    # Nenhuma coluna reconhecida - o cabecalho nao bate com o esperado. Sem
    # esta checagem, cada linha falhava por conta propria ("Time e
    # obrigatorio" repetido em toda linha) sem dizer a causa real.
    if rows.present? && rows.all?(&:blank?)
      message = 'Nenhuma coluna reconhecida - confira se o cabeçalho da planilha bate com o modelo baixado.'
      return Result.new(created: 0, skipped: 0, errors: [{ row: 0, message: message }], warnings: [])
    end

    entries = []
    row_errors = []
    row_warnings = []

    rows.each_with_index do |row, index|
      line_number = index + 2 # linha 1 e o cabecalho
      begin
        ticket, parent_number, warnings = import_row(row)
        entries << { ticket: ticket, parent_number: parent_number }
        warnings.each { |message| row_warnings << { row: line_number, message: message } }
      rescue StandardError => e
        row_errors << { row: line_number, message: e.message }
      end
    end

    link_parents!(entries)

    Result.new(created: entries.size, skipped: row_errors.size, errors: row_errors, warnings: row_warnings)
  end

  private

  def parse_csv
    first_line = csv_content.to_s.lines.first.to_s
    separator = first_line.count(';') > first_line.count(',') ? ';' : ','

    CSV.parse(csv_content, headers: true, col_sep: separator).map do |row|
      row.to_h.each_with_object({}) do |(header, value), normalized|
        key = HEADER_ALIASES[header.to_s.strip.downcase]
        normalized[key] = value if key
      end
    end
  end

  def import_row(row)
    warnings = []

    team = find_team!(row['time'])
    ticket_column = find_ticket_column!(team, row['estagio'])
    category = find_or_create_category!(team, row['categoria'])

    title = row['titulo'].to_s.strip
    raise 'Título é obrigatório' if title.blank?

    description = row['descricao'].to_s.strip
    raise 'Descrição é obrigatória' if description.blank?

    priority = resolve_priority(row['prioridade'], warnings)
    status = resolve_status(row['status'], warnings)
    company = find_company(row['cliente'], warnings)
    contact = find_contact(row['contato'], company, warnings)
    service_catalog_item = find_service_catalog_item(row['catalogo'], row['area'], row['item'], warnings)

    ticket = Ticket.new(
      account: account, team: team, ticket_column: ticket_column, ticket_category: category,
      title: title, description: description, priority: priority, status: status,
      company: company, contact: contact,
      created_at: parse_date(row['criado_em']) || Time.current,
      scheduled_at: parse_date(row['data']),
      custom_attributes: { 'imported_ticket_number' => row['numero'].to_s.strip.presence }.compact
    )
    ticket.save!

    ticket.classify!(service_catalog_item, nil) if service_catalog_item.present?
    post_import_note!(ticket, row)

    [ticket, row['ticket_pai'].to_s.strip.presence, warnings]
  end

  def find_team!(name)
    raise 'Time é obrigatório' if name.blank?

    team = account.teams.where('LOWER(name) = ?', name.to_s.strip.downcase).first
    raise "Time \"#{name}\" não encontrado" if team.blank?

    team
  end

  def find_ticket_column!(team, name)
    raise 'Estágio é obrigatório' if name.blank?

    column = team.ticket_columns.where('LOWER(name) = ?', name.to_s.strip.downcase).first
    raise "Estágio \"#{name}\" não encontrado na Mesa \"#{team.name}\"" if column.blank?

    column
  end

  # Categoria e obrigatoria pro Ticket (TicketOpening), mas e uma lista
  # simples por Mesa - diferente de Mesa/Estagio, criar uma que ainda nao
  # existe e seguro em vez de derrubar a linha inteira por causa de uma
  # categoria com nome levemente diferente do que ja esta cadastrado.
  def find_or_create_category!(team, name)
    raise 'Categoria é obrigatória' if name.blank?

    team.ticket_categories.where('LOWER(name) = ?', name.to_s.strip.downcase).first ||
      team.ticket_categories.create!(name: name.to_s.strip)
  end

  def find_company(name, warnings)
    return nil if name.blank?

    company = Company.where(account_id: account.id).where('LOWER(name) = ?', name.to_s.strip.downcase).first
    warnings << "Cliente \"#{name}\" não encontrado - ticket criado sem empresa vinculada" if company.blank?
    company
  end

  def find_contact(name, company, warnings)
    return nil if name.blank?

    contact = account.contacts.where('LOWER(name) = ?', name.to_s.strip.downcase).first
    if contact.blank?
      warnings << "Contato \"#{name}\" não encontrado - ticket criado sem solicitante vinculado"
      return nil
    end
    if company.present? && !contact.company_ids.include?(company.id)
      warnings << "Contato \"#{name}\" não pertence à empresa \"#{company.name}\" - ticket criado sem solicitante vinculado"
      return nil
    end
    contact
  end

  def find_service_catalog_item(catalog_name, area_name, item_name, warnings)
    return nil if catalog_name.blank? && area_name.blank? && item_name.blank?

    catalog = ServiceCatalog.where(account_id: account.id).where('LOWER(name) = ?', catalog_name.to_s.strip.downcase).first
    area = catalog&.service_catalog_areas&.where('LOWER(name) = ?', area_name.to_s.strip.downcase)&.first
    item = area&.service_catalog_items&.where('LOWER(name) = ?', item_name.to_s.strip.downcase)&.first

    if item.blank?
      path = [catalog_name, area_name, item_name].compact_blank.join(' > ')
      warnings << "Catálogo de Serviços \"#{path}\" não encontrado - ticket criado sem classificação"
    end
    item
  end

  def resolve_priority(value, warnings)
    key = value.to_s.strip.downcase
    return PRIORITY_ALIASES[key] if PRIORITY_ALIASES.key?(key)

    warnings << "Prioridade \"#{value}\" não reconhecida - usando \"Média\"" if value.present?
    'medium'
  end

  def resolve_status(value, warnings)
    key = value.to_s.strip.downcase
    return STATUS_ALIASES[key] if STATUS_ALIASES.key?(key)

    warnings << "Status \"#{value}\" não reconhecido - usando \"Aberto\"" if value.present?
    'open'
  end

  # Prioridade pro formato brasileiro (DD/MM/AAAA[ HH:MM]) - `Time.zone.parse`
  # sozinho assume mes/dia americano numa data ambigua (ex: "05/03/2024"
  # virava 3 de maio em vez de 5 de marco).
  def parse_date(value)
    text = value.to_s.strip
    return nil if text.blank?

    if (match = text.match(%r{\A(\d{1,2})/(\d{1,2})/(\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?\z}))
      day, month, year, hour, min, sec = match.captures
      year = "20#{year}" if year.length == 2
      return Time.zone.local(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i)
    end

    Time.zone.parse(text)
  rescue ArgumentError, TypeError
    nil
  end

  # "Numero original"/"Criado por" nao tem campo proprio no Ticket - fica
  # registrado aqui como uma entrada visivel no historico, em vez de sumir
  # dentro de custom_attributes onde ninguem olha.
  def post_import_note!(ticket, row)
    parts = []
    parts << "Número original: #{row['numero']}" if row['numero'].present?
    parts << "Criado originalmente por: #{row['criado_por']}" if row['criado_por'].present?
    return if parts.empty?

    ticket.ticket_activities.create!(
      account_id: ticket.account_id, user: nil, activity_type: :imported, new_value: parts.join(' | ')
    )
  end

  def link_parents!(entries)
    entries.each do |entry|
      parent_number = entry[:parent_number]
      next if parent_number.blank?

      parent = find_parent_by_original_number(parent_number, entries)
      next if parent.blank? || parent.id == entry[:ticket].id

      entry[:ticket].update!(parent: parent)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  def find_parent_by_original_number(number, entries)
    match = entries.find { |entry| entry[:ticket].custom_attributes['imported_ticket_number'] == number }
    return match[:ticket] if match

    Ticket.where(account_id: account.id).where("custom_attributes ->> 'imported_ticket_number' = ?", number).first
  end
end
