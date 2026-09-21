require 'roo'

# Imports the "Clientes" spreadsheet (Empresa + Contatos columns) from the
# Dados screen. One row can create/update a Company (matched by CPF/CNPJ) and
# any number of Contacts (each matched by identifier, then e-mail, then
# telefone) in the same pass, linking them all to that Company. Multiple
# contacts share one cell, each wrapped in "{...}" and separated by ';':
# '{1294494, Melina Mandrote, melina@x.com.br, 5518997595488, Comercial};{...}'
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
    company_name: 'Nome Fantasia',
    legal_name: 'Razão Social',
    cnpj: 'CPF/CNPJ',
    ie: 'IE',
    im: 'IM',
    contacts: 'Contatos (formato: {ID, Nome, E-mail, Telefone, Setor})',
    address_street: 'Rua',
    address_number: 'Número',
    address_neighborhood: 'Bairro',
    address_complement: 'Complemento',
    address_zip_code: 'CEP',
    city: 'Cidade',
    state: 'Estado',
    status: 'Status',
  }.freeze

  CONTACT_BLOCK_PATTERN = /\{([^{}]*)\}/.freeze
  CONTACT_FIELD_SEPARATOR = ','.freeze
  BLOCKED_STATUS_LABEL = 'bloqueado'.freeze

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

      parse_contacts(row).each do |contact_data|
        contact = find_or_build_contact(contact_data)
        contact.company_id = company.id if company
        contact.save!
        link_contact_to_company(contact, company) if company
      end
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
    document_digits = cell(row, :cnpj).gsub(/\D/, '')
    return nil if document_digits.blank?

    company = @account.companies.find_by(cnpj: document_digits) || @account.companies.new
    company.name = cell(row, :company_name) if cell(row, :company_name).present?
    company.legal_name = cell(row, :legal_name) if cell(row, :legal_name).present?
    company.cnpj = document_digits
    company.ie = cell(row, :ie) if cell(row, :ie).present?
    company.im = cell(row, :im) if cell(row, :im).present?
    company.address_street = cell(row, :address_street) if cell(row, :address_street).present?
    company.address_number = cell(row, :address_number) if cell(row, :address_number).present?
    company.address_neighborhood = cell(row, :address_neighborhood) if cell(row, :address_neighborhood).present?
    company.address_complement = cell(row, :address_complement) if cell(row, :address_complement).present?
    company.address_zip_code = cell(row, :address_zip_code) if cell(row, :address_zip_code).present?
    company.address_city = cell(row, :city) if cell(row, :city).present?
    company.address_state = cell(row, :state) if cell(row, :state).present?
    apply_status(company, row)
    company
  end

  # Deixa o "blocked" como esta quando a celula vem vazia (mesma regra dos
  # outros campos), em vez de reativar sem querer uma Empresa que foi
  # bloqueada manualmente fora da planilha.
  def apply_status(company, row)
    status_value = cell(row, :status)
    company.blocked = status_value.casecmp?(BLOCKED_STATUS_LABEL) if status_value.present?
  end

  # '{1294494, Melina Mandrote, melina@x.com.br, 5518997595488, Comercial};{...}'
  # Scans for "{...}" blocks directly instead of splitting on ';' first, so a
  # stray space or missing separator between blocks still parses correctly.
  def parse_contacts(row)
    raw = cell(row, :contacts)
    return [] if raw.blank?

    raw.scan(CONTACT_BLOCK_PATTERN).filter_map do |(block)|
      fields = block.split(CONTACT_FIELD_SEPARATOR).map { |field| field.to_s.strip }
      next if fields.all?(&:blank?)

      { identifier: fields[0], name: fields[1], email: fields[2], phone: fields[3], sector: fields[4] }
    end
  end

  def find_or_build_contact(contact_data)
    contact = existing_contact(contact_data) || @account.contacts.new
    contact.identifier = contact_data[:identifier] if contact_data[:identifier].present?
    contact.name = contact_data[:name] if contact_data[:name].present?
    contact.email = contact_data[:email].downcase if contact_data[:email].present?
    contact.phone_number = normalized_phone(contact_data[:phone]) if contact_data[:phone].present?
    apply_sector(contact, contact_data)
    contact
  end

  # Nao existe coluna propria para "setor" no Contact - guarda no
  # additional_attributes (jsonb livre) em vez de criar migracao para um
  # unico campo de texto.
  def apply_sector(contact, contact_data)
    return if contact_data[:sector].blank?

    contact.additional_attributes = (contact.additional_attributes || {}).merge('setor' => contact_data[:sector])
  end

  # O ID da planilha (sistema de origem da Ingrid) e a chave mais confiavel
  # entre reimportacoes - e-mail/telefone podem mudar, o ID nao.
  def existing_contact(contact_data)
    identifier = contact_data[:identifier]
    found_by_identifier = @account.contacts.find_by(identifier: identifier) if identifier.present?
    return found_by_identifier if found_by_identifier

    email = contact_data[:email]
    found_by_email = @account.contacts.from_email(email) if email.present?
    return found_by_email if found_by_email

    phone = normalized_phone(contact_data[:phone])
    return nil if phone.blank?

    @account.contacts.find_by(phone_number: phone)
  end

  def normalized_phone(phone)
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
