require 'roo'

# Imports the "Clientes" spreadsheet (Empresa + Contato columns) from the
# Dados screen. One row can create/update a Company (matched by CNPJ) and a
# Contact (matched by e-mail, then telefone) in the same pass, linking them.
#
# Mirrors app/jobs/data_import_job.rb (the legacy contacts CSV importer) in
# shape (status transitions), but records per-row failures as DataImportError
# instead of a failed_records CSV attachment, so they show up on the existing
# error_logs.csv download with no extra code. Feedback is in-app (the Dados
# screen polls the import's status), not by e-mail.
class ClientesImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    company_name: 'Nome da Empresa',
    cnpj: 'CNPJ',
    domain: 'Domínio da Empresa',
    city: 'Cidade',
    state: 'Estado',
    contact_name: 'Nome do Contato',
    email: 'E-mail do Contato',
    phone: 'Telefone do Contato',
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
    Rails.logger.error("[ClientesImportJob] #{e.class}: #{e.message}")
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
    ActiveRecord::Base.transaction do
      company = find_or_build_company(row)
      company&.save!

      contact = find_or_build_contact(row)
      contact.company_id = company.id if company
      contact.save!

      link_contact_to_company(contact, company) if company
    end
    @processed += 1
  rescue ActiveRecord::RecordInvalid => e
    record_error(row_number, e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    record_error(row_number, e.message)
  end

  def cell(row, key)
    row[COLUMNS[key]].to_s.strip
  end

  def find_or_build_company(row)
    cnpj_digits = cell(row, :cnpj).gsub(/\D/, '')
    return nil if cnpj_digits.blank?

    company = @account.companies.find_by(cnpj: cnpj_digits) || @account.companies.new
    company.name = cell(row, :company_name) if cell(row, :company_name).present?
    company.cnpj = cnpj_digits
    company.domain = cell(row, :domain) if cell(row, :domain).present?
    company.address_city = cell(row, :city) if cell(row, :city).present?
    company.address_state = cell(row, :state) if cell(row, :state).present?
    company
  end

  def find_or_build_contact(row)
    contact = existing_contact(row) || @account.contacts.new
    contact.name = cell(row, :contact_name) if cell(row, :contact_name).present?
    contact.email = cell(row, :email).downcase if cell(row, :email).present?
    contact.phone_number = normalized_phone(row) if cell(row, :phone).present?
    contact
  end

  def existing_contact(row)
    email = cell(row, :email)
    found_by_email = @account.contacts.from_email(email) if email.present?
    return found_by_email if found_by_email

    phone = normalized_phone(row)
    return nil if phone.blank?

    @account.contacts.find_by(phone_number: phone)
  end

  def normalized_phone(row)
    phone = cell(row, :phone)
    return nil if phone.blank?

    phone.start_with?('+') ? phone : "+#{phone.gsub(/\D/, '')}"
  end

  def link_contact_to_company(contact, company)
    already_linked = CompanyContact.exists?(contact_id: contact.id, company_id: company.id)
    CompanyContact.find_or_create_by!(contact_id: contact.id, company_id: company.id)
    Company.increment_counter(:contacts_count, company.id) unless already_linked
  end

  def record_error(row_number, message)
    @failed += 1
    @data_import.import_errors.create!(
      error_code: 'clientes_import_row_error',
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
