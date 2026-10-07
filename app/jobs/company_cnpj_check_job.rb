require 'roo'

# Importacao "comparativa": nao cria nem atualiza empresa nenhuma. So le uma
# planilha de CNPJs e devolve, linha a linha, se aquela empresa ja esta
# cadastrada na conta ou nao - util pra comparar uma base de clientes externa
# contra o que ja existe no Chatwoot antes de decidir o que importar de
# verdade.
#
# Tambem calcula o INVERSO - quais empresas JA CADASTRADAS no sistema NAO
# aparecem na planilha - e guarda os ids em `stats['unmatched_company_ids']`
# (coluna jsonb que ja existe em todo DataImport). Isso so' alimenta dados
# pra quem quiser excluir essas empresas depois (ver
# `DataImports::UnmatchedCompaniesDeleter` e
# `DataImportsController#destroy_unmatched_companies`) - este job em si
# continua sem apagar nada.
#
# E tambem acha empresas DUPLICADAS dentro do proprio sistema (independe da
# planilha) - ver `record_duplicate_companies` pra regra completa.
#
# Reaproveita a mesma infraestrutura das outras importacoes (status,
# `processed_records`/`total_records`, `DataImportError` + o download de
# "error_logs" ja existente) sem nenhuma tela ou rota nova: os CNPJs
# encontrados so contam pra `processed_records` (o resumo "X de Y"), os NAO
# encontrados viram uma linha de log de erro (baixavel pelo mesmo botao
# "baixar detalhes" que os outros cartoes de planilha ja tem) - por isso o
# `kind` do erro aqui e' 'not_registered', nao 'failed': `DataImportError`
# classifica 'failed'/'skipped' como "skip log" (uma aba separada, menos em
# evidencia); qualquer outro kind cai no bucket "error_logs" padrao, que e' o
# que o cartao da tela Dados mostra e baixa direto.
class CompanyCnpjCheckJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    name: 'Nome',
    cnpj: 'CNPJ',
  }.freeze

  def perform(data_import)
    @data_import = data_import
    @account = data_import.account
    @processed = 0
    @failed = 0
    @sheet_cnpjs = []

    @data_import.update!(status: :processing)
    process_rows
    record_unmatched_companies
    record_duplicate_companies
    @data_import.update!(status: :completed, processed_records: @processed, total_records: @processed + @failed)
  rescue StandardError => e
    @data_import.update!(status: :failed)
    Rails.logger.error("[CompanyCnpjCheckJob] #{e.class}: #{e.message}")
  end

  private

  def process_rows
    with_import_file do |path|
      sheet = Roo::Spreadsheet.open(path)
      headers = sheet.row(1).map { |header| header.to_s.strip }

      (2..sheet.last_row).each do |row_number|
        values = sheet.row(row_number)
        next if values.compact.blank?

        check_row(headers.zip(values).to_h, row_number)
      end
    end
  end

  def check_row(row, row_number)
    name = cell(row, :name)
    document_digits = cell(row, :cnpj).gsub(/\D/, '')
    raise "Nenhum CNPJ informado na linha #{row_number}" if document_digits.blank?

    @sheet_cnpjs << document_digits

    if @account.companies.exists?(cnpj: document_digits)
      @processed += 1
    else
      record_not_registered(row_number, name, document_digits)
    end
  rescue StandardError => e
    record_error(row_number, e.message)
  end

  # So' marca pra exclusao quando a planilha tem pelo menos um CNPJ valido -
  # uma planilha vazia/toda invalida NAO pode marcar "todo mundo" como fora
  # dela (`where.not(cnpj: [])` nao filtra nada, marcaria o cadastro inteiro
  # por engano).
  def record_unmatched_companies
    return if @sheet_cnpjs.empty?

    unmatched_ids = @account.companies.where.not(cnpj: [nil, '']).where.not(cnpj: @sheet_cnpjs).pluck(:id)
    @data_import.update!(
      stats: @data_import.stats.to_h.merge(
        'unmatched_company_ids' => unmatched_ids,
        'unmatched_companies_count' => unmatched_ids.size
      )
    )
  end

  # "Duplicada" = mais de uma Empresa da conta com o MESMO nome (ignora
  # maiusculo/minusculo e espaco nas pontas). O banco ja tem indice unico de
  # CNPJ por conta (`index_companies_on_account_and_cnpj`) - duas Empresas
  # NUNCA tem o mesmo CNPJ preenchido - entao a duplicata de verdade e' quase
  # sempre um cadastro antigo SEM CNPJ que sobrou quando a Empresa certa foi
  # cadastrada de novo ja com o CNPJ.
  #
  # Regra, pra nao arriscar apagar duas empresas DIFERENTES que so'
  # coincidem no nome:
  # - Mais de uma empresa do grupo com CNPJ preenchido -> grupo INTEIRO
  #   ignorado (nao da pra saber qual e' a "certa" so' pelo nome).
  # - So' uma com CNPJ -> essa fica, as outras (sem CNPJ) sao marcadas.
  # - Nenhuma com CNPJ -> fica a mais antiga, as demais sao marcadas.
  def record_duplicate_companies
    duplicate_ids = @account.companies
                             .where.not(name: [nil, ''])
                             .select(:id, :name, :cnpj, :created_at)
                             .order(:created_at, :id)
                             .group_by { |company| company.name.to_s.strip.upcase }
                             .select { |name, companies| name.present? && companies.size > 1 }
                             .flat_map { |_name, companies| duplicates_within(companies) }

    @data_import.update!(
      stats: @data_import.stats.to_h.merge(
        'duplicate_company_ids' => duplicate_ids,
        'duplicate_companies_count' => duplicate_ids.size
      )
    )
  end

  def duplicates_within(companies)
    with_cnpj, without_cnpj = companies.partition { |company| company.cnpj.present? }
    return [] if with_cnpj.size > 1
    return without_cnpj.map(&:id) if with_cnpj.size == 1

    # Nenhuma tem CNPJ - `companies` ja vem ordenada por created_at (a query
    # em `record_duplicate_companies`), entao a primeira e' a mais antiga.
    without_cnpj.drop(1).map(&:id)
  end

  def cell(row, key)
    row[COLUMNS[key]].to_s.strip
  end

  def record_not_registered(row_number, name, document_digits)
    @failed += 1
    label = name.present? ? "#{name} (CNPJ #{document_digits})" : "CNPJ #{document_digits}"
    @data_import.import_errors.create!(
      error_code: 'company_cnpj_check_not_registered',
      message: "#{label} ainda nao cadastrado no sistema",
      source_object_type: 'row',
      source_object_id: row_number.to_s,
      details: { kind: 'not_registered', cnpj: document_digits, nome: name }
    )
  end

  def record_error(row_number, message)
    @failed += 1
    @data_import.import_errors.create!(
      error_code: 'company_cnpj_check_row_error',
      message: message,
      source_object_type: 'row',
      source_object_id: row_number.to_s,
      details: { kind: 'not_registered' }
    )
  end

  def with_import_file
    temp_dir = Rails.root.join('tmp/imports')
    FileUtils.mkdir_p(temp_dir)

    @data_import.import_file.open(tmpdir: temp_dir) do |file|
      yield file.path
    end
  end
end
