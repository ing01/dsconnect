require 'roo'

# Segunda opcao de importacao de Empresa, na aba Planilhas da tela Dados:
# so tres colunas (Codigo, CNPJ, Prioridade), separada da importacao
# "Clientes" (que tambem traz nome, endereco e contatos - ver
# `ClientesImportJob`, que este job espelha em formato/status).
#
# So ATUALIZA empresa ja existente - a planilha nao tem "Nome", entao nao da
# pra criar uma empresa do zero aqui. Casa primeiro por Codigo (mais
# confiavel entre reimportacoes, decisao da Ingrid), senao por CNPJ - o que
# tambem serve pra gravar o Codigo pela primeira vez numa empresa que so
# tinha CNPJ ate entao.
#
# "Prioridade" vira `Company#client_level` como valor INICIAL, nao trava
# permanente: se a empresa ja tem (ou vier a ter) mensalidade configurada,
# `Company#compute_client_level` recalcula e substitui esse valor - decisao
# confirmada com a Ingrid. Sem mensalidade, o valor importado fica valendo.
class CompanyPriorityImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    codigo: 'Código',
    cnpj: 'CNPJ',
    priority: 'Prioridade',
  }.freeze

  # Aceita com ou sem acento, singular/masculino, em qualquer caixa -
  # `normalize_priority_label` remove acento e caixa antes de comparar aqui.
  PRIORITY_ALIASES = {
    'baixa' => 1, 'baixo' => 1, '1' => 1,
    'media' => 2, 'medio' => 2, '2' => 2,
    'alta' => 3, 'alto' => 3, '3' => 3,
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
    Rails.logger.error("[CompanyPriorityImportJob] #{e.class}: #{e.message}")
  end

  private

  def process_rows
    with_import_file do |path|
      sheet = Roo::Spreadsheet.open(path)
      headers = sheet.row(1).map { |header| header.to_s.strip }

      (2..sheet.last_row).each do |row_number|
        values = sheet.row(row_number)
        next if values.compact.blank?

        process_row(headers.zip(values).to_h, row_number)
      end
    end
  end

  def process_row(row, row_number)
    codigo = cell(row, :codigo)
    document_digits = cell(row, :cnpj).gsub(/\D/, '')
    raise "Nenhum Codigo ou CNPJ informado na linha #{row_number}" if codigo.blank? && document_digits.blank?

    company = find_company(codigo, document_digits)
    raise "Empresa nao encontrada para Codigo '#{codigo}' / CNPJ '#{document_digits}'" if company.blank?

    company.codigo = codigo if codigo.present?
    company.cnpj = document_digits if document_digits.present?
    apply_priority(company, row)
    company.save!
    @processed += 1
  rescue ActiveRecord::RecordInvalid => e
    record_error(row_number, e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    record_error(row_number, e.message)
  end

  def cell(row, key)
    row[COLUMNS[key]].to_s.strip
  end

  # Codigo primeiro (mais confiavel entre reimportacoes), senao CNPJ - tambem
  # e' assim que uma empresa que so tinha CNPJ ganha o Codigo pela primeira vez.
  def find_company(codigo, document_digits)
    (codigo.present? && @account.companies.find_by(codigo: codigo)) ||
      (document_digits.present? && @account.companies.find_by(cnpj: document_digits)) || nil
  end

  def apply_priority(company, row)
    label = cell(row, :priority)
    return if label.blank?

    level = PRIORITY_ALIASES[normalize_priority_label(label)]
    raise "Prioridade '#{label}' invalida (use Baixa, Media ou Alta)" if level.blank?

    company.client_level = level
  end

  def normalize_priority_label(label)
    ActiveSupport::Inflector.transliterate(label).strip.downcase
  end

  def record_error(row_number, message)
    @failed += 1
    @data_import.import_errors.create!(
      error_code: 'company_priority_import_row_error',
      message: message,
      source_object_type: 'row',
      source_object_id: row_number.to_s,
      details: { kind: 'failed' }
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
