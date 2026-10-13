require 'csv'

# Importa tickets de uma planilha (CSV) exportada de outro sistema -
# Configuracoes > Tickets > Importar (roda em segundo plano, ver
# Tickets::ImportJob). Cada linha e processada isolada: uma falha numa linha
# (ex: Mesa/Estagio inexistente) so descarta aquela linha, nunca o lote inteiro.
#
# Cabecalho esperado (nomes exatos, sem acento tambem funciona - ver
# HEADER_ALIASES): Numero, Cliente, Titulo, Descricao, Status, Estagio,
# Contato, Time, Prioridade, Catalogo de Servicos, Area do Catalogo de
# Servicos, Item, Ticket pai, Criado por, Criado em, Categoria, Data,
# Desenvolvimento (chave do Jira - aparece na aba "Desenvolvimento" do
# ticket).
#
# Duas passadas: a primeira cria/atualiza os tickets (sem "Ticket pai"
# ainda), a segunda liga o "Ticket pai" usando o "Numero" original que cada
# ticket guarda em `custom_attributes['imported_ticket_number']` - funciona
# tanto para um pai importado no mesmo arquivo quanto num arquivo anterior.
#
# Reimportar o mesmo "Numero" ATUALIZA o ticket existente com o que estiver
# na planilha, em vez de pular a linha - e o "Numero" tambem passa a ser o
# proprio `display_id` do ticket (o "#123" que aparece em toda a tela), nao
# so' um dado guardado em `custom_attributes`. Isso faz o ID do ticket no
# Chatwoot bater com o ID da planilha de origem, sem renumerar nada.
#
# Uma planilha real pode ter dezenas de milhares de linhas - por isso Mesa,
# Estagio, Categoria, Cliente, Contato e Catalogo de Servicos sao carregados
# so uma vez cada (memoizados nos metodos `*_by_*` abaixo) em vez de uma
# consulta nova por linha.
class Tickets::ImportService
  Result = Struct.new(:created, :updated, :skipped, :errors, :warnings, keyword_init: true)

  # A cada quantas linhas o progresso e salvo - por linha seria uma escrita a
  # mais no banco por ticket, demais para dezenas de milhares de linhas.
  PROGRESS_CHECKPOINT = 50

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

  # Varias planilhas de origem (ex: Movidesk) guardam a descricao como um
  # texto corrido, com campos tipo "CLIENTE:", "BACKUP:" colados direto no
  # texto anterior - a tela de origem so separava visualmente, sem gravar
  # quebra de linha nenhuma no dado de verdade. Reconhece um "RÓTULO:" em
  # maiuscula colado (sem espaco) ao que veio antes e comeca uma linha nova
  # ali. So pega quando o texto anterior termina em minuscula/pontuacao -
  # quando os dois lados do ponto de colagem sao maiuscula (ex:
  # "...VISÃOLOCAL DO BUG:") nao da pra saber com certeza onde um termina e o
  # outro comeca, entao esses casos continuam colados.
  DESCRIPTION_LABEL_BREAK_REGEX = /(?<=[^\s\p{Lu}])(\p{Lu}[\p{Lu}\sº°]{1,30}:)/

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
    'data' => 'data',
    'desenvolvimento' => 'desenvolvimento'
  }.freeze

  pattr_initialize [:account!, :csv_content!, :ticket_import!]

  def perform
    parsed_rows = parse_csv
    # Nenhuma coluna reconhecida - o cabecalho nao bate com o esperado. Sem
    # esta checagem, cada linha falhava por conta propria ("Time e
    # obrigatorio" repetido em toda linha) sem dizer a causa real.
    if parsed_rows.present? && parsed_rows.all?(&:blank?)
      message = 'Nenhuma coluna reconhecida - confira se o cabeçalho da planilha bate com o modelo baixado.'
      return Result.new(created: 0, updated: 0, skipped: 0, errors: [{ row: 0, message: message }], warnings: [])
    end

    # O Excel costuma deixar centenas de milhares de linhas vazias no fim do
    # CSV (o "intervalo usado" da planilha cresce mesmo sem conteudo real) -
    # sem filtrar isso, uma planilha com poucas dezenas de milhares de
    # tickets de verdade aparecia como se tivesse mais de 1 milhao de linhas.
    rows = parsed_rows.reject { |row| row.values.all?(&:blank?) }
    ticket_import.update!(total_rows: rows.size)

    entries = []
    created_count = 0
    updated_count = 0
    row_errors = []
    row_warnings = []

    rows.each_with_index do |row, index|
      line_number = index + 2 # linha 1 e o cabecalho
      begin
        ticket, parent_number, action, warnings = import_row(row)
        entries << { ticket: ticket, parent_number: parent_number }
        created_count += 1 if action == :created
        updated_count += 1 if action == :updated
        warnings.each { |message| row_warnings << { row: line_number, message: message } }
      rescue StandardError => e
        row_errors << { row: line_number, message: e.message }
      end
      checkpoint_progress!(index + 1, rows.size)
    end

    link_parents!(entries)

    Result.new(created: created_count, updated: updated_count, skipped: row_errors.size, errors: row_errors, warnings: row_warnings)
  end

  private

  def checkpoint_progress!(count, total)
    return unless (count % PROGRESS_CHECKPOINT).zero? || count == total

    ticket_import.update_column(:processed_rows, count) # rubocop:disable Rails/SkipsModelValidations
  end

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
    original_number = row['numero'].to_s.strip.presence

    team = find_team!(row['time'])
    ticket_column = find_ticket_column!(team, row['estagio'])
    category = find_or_create_category!(team, row['categoria'])

    title = row['titulo'].to_s.strip
    raise 'Título é obrigatório' if title.blank?

    description = normalize_description(row['descricao'].to_s.strip)
    raise 'Descrição é obrigatória' if description.blank?

    priority = resolve_priority(row['prioridade'], warnings)
    status = resolve_status(row['status'], warnings)
    company = find_company(row['cliente'], warnings)
    contact = find_contact(row['contato'], company, warnings)
    service_catalog_item = find_service_catalog_item(row['catalogo'], row['area'], row['item'], warnings)

    attributes = {
      team: team, ticket_column: ticket_column, ticket_category: category,
      title: title, description: description, priority: priority, status: status,
      company: company, contact: contact,
      created_at: parse_date(row['criado_em']) || Time.current,
      scheduled_at: parse_date(row['data']),
      jira_key: row['desenvolvimento'].to_s.strip.presence
    }

    # Reprocessar o mesmo arquivo (ex: depois de corrigir um erro, ou uma
    # planilha atualizada do sistema de origem) nao duplica o ticket - o
    # "Numero" original e' o unico jeito de saber que e' o mesmo ticket, e a
    # linha agora ATUALIZA o que ja existe em vez de so' avisar e pular.
    existing = original_number && existing_ticket_numbers.include?(original_number) ? find_existing_by_number(original_number) : nil

    ticket, action =
      if existing
        update_imported_ticket!(existing, attributes, original_number, warnings)
      else
        create_imported_ticket!(attributes, original_number, warnings, row)
      end

    # Um ticket importado ja pode nascer (ou ja estar) Fechado/Cancelado -
    # e' historico - mas TicketFinalizable trava qualquer alteracao depois
    # disso, inclusive a classificacao e os campos que a propria importacao
    # acabou de resolver. Mesma excecao administrativa que
    # Tickets::MergeService ja usa pra fechar e depois anotar o motivo no
    # mesmo ticket.
    ticket.as_administrative_change do
      ticket.classify!(service_catalog_item, nil) if service_catalog_item.present?
    end

    [ticket, row['ticket_pai'].to_s.strip.presence, action, warnings]
  end

  def create_imported_ticket!(attributes, original_number, warnings, row)
    display_id = resolve_display_id(original_number, warnings)
    ticket = Ticket.new(attributes.merge(
                           account: account, display_id: display_id,
                           custom_attributes: { 'imported_ticket_number' => original_number }.compact
                         ))
    with_friendly_display_id_error(original_number) { ticket.save! }
    existing_ticket_numbers << original_number if original_number
    post_import_note!(ticket, row)
    [ticket, :created]
  end

  def update_imported_ticket!(ticket, attributes, original_number, warnings)
    display_id = resolve_display_id(original_number, warnings)
    attributes = attributes.merge(display_id: display_id) if display_id
    # `merge`, nao substitui: o ticket pode ter ganhado outros
    # `custom_attributes` desde a importacao original (de outra tela, de uma
    # automacao) - sobrescrever o jsonb inteiro apagaria isso.
    attributes = attributes.merge(
      custom_attributes: (ticket.custom_attributes || {}).merge('imported_ticket_number' => original_number).compact
    )
    with_friendly_display_id_error(original_number) do
      ticket.as_administrative_change { ticket.update!(attributes) }
    end
    [ticket, :updated]
  end

  # O "Numero" da planilha passa a ser o `display_id` do ticket (o "#123" que
  # aparece em toda a tela) sempre que for numerico - e' assim que o ID bate
  # com a planilha de origem, sem o Chatwoot renumerar por conta propria. Um
  # "Numero" nao-numerico nao serve de display_id (a coluna e' inteiro); o
  # ticket entao recebe o ID interno automatico de sempre.
  def resolve_display_id(original_number, warnings)
    return nil if original_number.blank?

    unless original_number.match?(/\A\d+\z/)
      warnings << "Número \"#{original_number}\" não é numérico - o ticket recebeu um ID interno novo em vez do número original"
      return nil
    end

    original_number.to_i
  end

  # So' existe UM "Numero" por conta (o indice unico de `display_id`) - se
  # outro ticket (manual, ou de outra importacao) ja usa esse numero, nao da
  # pra manter o original sem renumerar o outro ticket, o que a importacao
  # nunca faz por conta propria. Vira erro na linha, nao um aviso silencioso.
  def with_friendly_display_id_error(original_number)
    yield
  rescue ActiveRecord::RecordNotUnique
    raise "Número #{original_number} já pertence a outro ticket nesta conta - não foi possível manter o mesmo número"
  end

  # Todo "Numero" ja gravado nesta conta antes deste lote comecar, mais os
  # que este proprio lote ja criou ate agora - uma unica consulta, em vez de
  # perguntar ao banco de novo a cada linha (o que so ficaria mais lento a
  # cada ticket novo inserido).
  def existing_ticket_numbers
    @existing_ticket_numbers ||= Ticket.where(account_id: account.id)
                                        .where("custom_attributes ->> 'imported_ticket_number' IS NOT NULL")
                                        .pluck(Arel.sql("custom_attributes ->> 'imported_ticket_number'"))
                                        .to_set
  end

  # So' chamada quando `existing_ticket_numbers` ja confirmou que o "Numero"
  # esta' presente - o Set evita essa consulta pra cada uma das (potencialmente
  # dezenas de milhares de) linhas novas, so' paga o preco pra uma linha que
  # e' de fato uma reimportacao.
  def find_existing_by_number(number)
    Ticket.where(account_id: account.id)
          .where("custom_attributes ->> 'imported_ticket_number' = ?", number)
          .first
  end

  # --- Caches: uma consulta por Mesa/lista, nao uma por linha da planilha ---

  def teams_by_name
    @teams_by_name ||= account.teams.each_with_object({}) { |t, h| h[t.name.to_s.strip.downcase] = t }
  end

  def ticket_columns_by_team(team)
    @ticket_columns_by_team ||= {}
    @ticket_columns_by_team[team.id] ||=
      team.ticket_columns.each_with_object({}) { |c, h| h[c.name.to_s.strip.downcase] = c }
  end

  # Mutavel de proposito: uma Categoria criada por uma linha precisa ser
  # reaproveitada pelas linhas seguintes da mesma Mesa, sem bater no banco de
  # novo (e sem tentar criar a mesma Categoria duas vezes).
  def ticket_categories_by_team(team)
    @ticket_categories_by_team ||= {}
    @ticket_categories_by_team[team.id] ||=
      team.ticket_categories.each_with_object({}) { |c, h| h[c.name.to_s.strip.downcase] = c }
  end

  def companies_by_name
    @companies_by_name ||=
      Company.where(account_id: account.id).each_with_object({}) { |c, h| h[c.name.to_s.strip.downcase] = c }
  end

  def contacts_by_name
    @contacts_by_name ||= account.contacts.each_with_object({}) { |c, h| h[c.name.to_s.strip.downcase] = c }
  end

  # Inclui as Areas e os Itens de cada Catalogo - a busca por Area/Item vira
  # busca em array (`find`), sem consulta nenhuma por linha.
  def service_catalogs_by_name
    @service_catalogs_by_name ||= ServiceCatalog.where(account_id: account.id)
                                                 .includes(service_catalog_areas: :service_catalog_items)
                                                 .each_with_object({}) { |c, h| h[c.name.to_s.strip.downcase] = c }
  end

  def find_team!(name)
    raise 'Time é obrigatório' if name.blank?

    team = teams_by_name[name.to_s.strip.downcase]
    raise "Time \"#{name}\" não encontrado" if team.blank?

    team
  end

  def find_ticket_column!(team, name)
    raise 'Estágio é obrigatório' if name.blank?

    column = ticket_columns_by_team(team)[name.to_s.strip.downcase]
    raise "Estágio \"#{name}\" não encontrado na Mesa \"#{team.name}\"" if column.blank?

    column
  end

  DEFAULT_CATEGORY_NAME = 'Importado'.freeze

  # Categoria e obrigatoria pro Ticket (TicketOpening), mas e uma lista
  # simples por Mesa - diferente de Mesa/Estagio, criar uma que ainda nao
  # existe e seguro em vez de derrubar a linha inteira por causa de uma
  # categoria com nome levemente diferente do que ja esta cadastrado. Uma
  # linha sem Categoria (comum em exportacoes reais) cai numa categoria
  # generica em vez de ser descartada por causa so desse campo.
  def find_or_create_category!(team, name)
    key = name.to_s.strip.downcase.presence || DEFAULT_CATEGORY_NAME.downcase
    resolved_name = name.to_s.strip.presence || DEFAULT_CATEGORY_NAME
    cache = ticket_categories_by_team(team)
    cache[key] ||= team.ticket_categories.create!(name: resolved_name)
  end

  def find_company(name, warnings)
    return nil if name.blank?

    company = companies_by_name[name.to_s.strip.downcase]
    warnings << "Cliente \"#{name}\" não encontrado - ticket criado sem empresa vinculada" if company.blank?
    company
  end

  def find_contact(name, company, warnings)
    return nil if name.blank?

    contact = contacts_by_name[name.to_s.strip.downcase]
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

    catalog = service_catalogs_by_name[catalog_name.to_s.strip.downcase]
    area = catalog&.service_catalog_areas&.find { |a| a.name.to_s.strip.downcase == area_name.to_s.strip.downcase }
    item = area&.service_catalog_items&.find { |i| i.name.to_s.strip.downcase == item_name.to_s.strip.downcase }

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

  # Prioridade pro formato brasileiro (DD/MM/AAAA[, HH:MM]) - `Time.zone.parse`
  # sozinho assume mes/dia americano numa data ambigua (ex: "05/03/2024"
  # virava 3 de maio em vez de 5 de marco). A virgula antes da hora e opcional
  # porque foi assim que o sistema de origem (Movidesk) exportou as datas.
  def parse_date(value)
    text = value.to_s.strip
    return nil if text.blank?

    if (match = text.match(%r{\A(\d{1,2})/(\d{1,2})/(\d{2,4})(?:,?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?)?\z}))
      day, month, year, hour, min, sec = match.captures
      year = "20#{year}" if year.length == 2
      return Time.zone.local(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i)
    end

    Time.zone.parse(text)
  rescue ArgumentError, TypeError
    nil
  end

  def normalize_description(text)
    text.gsub(DESCRIPTION_LABEL_BREAK_REGEX) { "\n\n#{Regexp.last_match(1)}" }
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

      # Mesma excecao administrativa de import_row: um "Ticket pai" so e
      # ligado depois que ambos os tickets ja existem (segunda passada), e um
      # dos dois pode ja ter nascido Fechado/Cancelado.
      entry[:ticket].as_administrative_change { entry[:ticket].update!(parent: parent) }
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
