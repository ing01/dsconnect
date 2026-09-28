require 'roo'

# Importacao "comparativa": nao cria nem atualiza nada. So le uma planilha de
# CNPJs e devolve, linha a linha, se aquela empresa ja esta cadastrada na
# conta ou nao - util pra comparar uma base de clientes externa contra o que
# ja existe no Chatwoot antes de decidir o que importar de verdade.
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

    @data_import.update!(status: :processing)
    process_rows
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

    if @account.companies.exists?(cnpj: document_digits)
      @processed += 1
    else
      record_not_registered(row_number, name, document_digits)
    end
  rescue StandardError => e
    record_error(row_number, e.message)
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
