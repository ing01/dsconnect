require 'roo'

# Importacao de Nicho/Subnicho/Nivel/Especialista por planilha, na aba
# Planilhas da tela Dados (pedido da Ingrid, 2026-11-17). Mesmo formato/status
# dos demais jobs de Empresa (`CompanyClassificationImportJob`,
# `CompanyPriorityImportJob`).
#
# So ATUALIZA empresa ja existente - casa SOMENTE por CNPJ (sem Codigo, por
# pedido explicito: "ler pelo CNPJ pra identificar o cliente"). Nicho e
# Subnicho sao criados automaticamente quando o nome da planilha ainda nao
# existe na conta (comparacao sem diferenciar maiusculas/minusculas, pra nao
# multiplicar o mesmo Nicho por causa de digitacao diferente). Especialista
# nao encontrado NAO falha a linha - os outros campos da linha sao salvos
# normalmente, e o aviso vai pros "registros ignorados" (nao pro contador de
# erros), pra nao dar a falsa impressao de que a linha inteira nao foi
# aplicada.
class CompanyNicheImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    cnpj: 'CNPJ',
    niche: 'Nicho',
    sub_niche: 'Subnicho',
    level: 'Nível',
    specialist: 'Especialista',
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
    Rails.logger.error("[CompanyNicheImportJob] #{e.class}: #{e.message}")
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
    document_digits = cell(row, :cnpj).gsub(/\D/, '')
    raise "Nenhum CNPJ informado na linha #{row_number}" if document_digits.blank?

    company = @account.companies.find_by(cnpj: document_digits)
    raise "Empresa nao encontrada para o CNPJ '#{document_digits}'" if company.blank?

    apply_niche(company, row)
    apply_sub_niche(company, row)
    apply_level(company, row, row_number)
    specialist_warning = apply_specialist(company, row)
    company.save!
    record_warning(row_number, specialist_warning) if specialist_warning
    @processed += 1
  rescue ActiveRecord::RecordInvalid => e
    record_error(row_number, e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    record_error(row_number, e.message)
  end

  def cell(row, key)
    row[COLUMNS[key]].to_s.strip
  end

  def apply_niche(company, row)
    label = cell(row, :niche)
    return if label.blank?

    company.company_niche = find_or_create_lookup(CompanyNiche, label)
  end

  def apply_sub_niche(company, row)
    label = cell(row, :sub_niche)
    return if label.blank?

    company.company_sub_niche = find_or_create_lookup(CompanySubNiche, label)
  end

  def find_or_create_lookup(model_class, label)
    model_class.where(account_id: @account.id).where('LOWER(name) = ?', label.downcase).first ||
      model_class.create!(account: @account, name: label)
  end

  def apply_level(company, row, row_number)
    label = cell(row, :level)
    return if label.blank?

    level = Integer(label, exception: false)
    raise "Nível '#{label}' inválido na linha #{row_number} (use um número de 1 a 5)" if level.blank? || !(1..5).cover?(level)

    company.classification_level = level
  end

  # Nao faz a empresa falhar: devolve o aviso para quem chamou registrar
  # separadamente (so DEPOIS do `company.save!` ter dado certo).
  def apply_specialist(company, row)
    label = cell(row, :specialist)
    return nil if label.blank?

    agent = agents_by_identifier[label.downcase]
    return "Especialista \"#{label}\" não encontrado - campo não alterado" if agent.blank?

    company.specialist = agent
    nil
  end

  def agents_by_identifier
    @agents_by_identifier ||= @account.users.each_with_object({}) do |user, hash|
      hash[user.name.to_s.strip.downcase] = user
      hash[user.email.to_s.strip.downcase] = user
    end
  end

  def record_error(row_number, message)
    @failed += 1
    @data_import.import_errors.create!(
      error_code: 'company_niche_import_row_error',
      message: message,
      source_object_type: 'row',
      source_object_id: row_number.to_s,
      details: { kind: 'failed' }
    )
  end

  def record_warning(row_number, message)
    @data_import.import_errors.create!(
      error_code: 'company_niche_import_row_warning',
      message: message,
      source_object_type: 'row',
      source_object_id: row_number.to_s,
      details: { kind: 'skipped' }
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
