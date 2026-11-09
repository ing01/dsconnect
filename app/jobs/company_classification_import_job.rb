require 'roo'

# Importacao de Classificacao de Empresa por planilha, na aba Planilhas da
# tela Dados - mesmo formato/status de `CompanyPriorityImportJob`, mas pro
# campo `Company#classification_level` (1 a 5, manual e INDEPENDENTE da
# Prioridade automatica - pedido da Ingrid, 2026-11-09).
#
# So ATUALIZA empresa ja existente - a planilha nao tem "Nome", entao nao da
# pra criar uma empresa do zero aqui. Casa primeiro por Codigo, senao por
# CNPJ (mesma ordem de `CompanyPriorityImportJob`).
class CompanyClassificationImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    codigo: 'Código',
    cnpj: 'CNPJ',
    classification: 'Classificação',
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
    Rails.logger.error("[CompanyClassificationImportJob] #{e.class}: #{e.message}")
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
    apply_classification(company, row, row_number)
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

  def find_company(codigo, document_digits)
    (codigo.present? && @account.companies.find_by(codigo: codigo)) ||
      (document_digits.present? && @account.companies.find_by(cnpj: document_digits)) || nil
  end

  def apply_classification(company, row, row_number)
    label = cell(row, :classification)
    return if label.blank?

    level = Integer(label, exception: false)
    raise "Classificação '#{label}' inválida na linha #{row_number} (use um número de 1 a 5)" if level.blank? || !(1..5).cover?(level)

    company.classification_level = level
  end

  def record_error(row_number, message)
    @failed += 1
    @data_import.import_errors.create!(
      error_code: 'company_classification_import_row_error',
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
