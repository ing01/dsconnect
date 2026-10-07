require 'roo'

# Importa a planilha de "Contatos/Solicitantes" (Dados > Importação de
# Contatos/Solicitantes) - diferente da planilha "Clientes"
# (ver `ClientesImportJob`), aqui CADA LINHA E' UM CONTATO (nao empacota
# varios contatos numa celula por empresa) e NAO HA COLUNA DE CNPJ.
#
# Pensada pra quando a planilha de origem nao tem o CNPJ da empresa pra casar
# com certeza (caso da Ingrid): a empresa so' e' vinculada quando o "Nome
# Fantasia" da planilha bate EXATAMENTE (sensivel a mai'usculas/minusculas,
# so' tira espaco nas pontas) com uma Empresa ja cadastrada na conta. Nunca
# cria empresa nova e nunca vincula por aproximacao/parecido - se o nome nao
# bater, o contato ainda e' importado normalmente, so' fica sem vinculo
# (e isso aparece no log de erros da importacao, pra revisar).
class SolicitantesImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    identifier: 'ID',
    name: 'Nome',
    email: 'E-mail',
    phone: 'Telefone',
    sector: 'Setor',
    company_name: 'Nome Fantasia da Empresa (opcional - só vincula se for EXATAMENTE igual ao cadastrado)',
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
    Rails.logger.error("[SolicitantesImportJob] #{e.class}: #{e.message}")
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
    contact = nil
    ActiveRecord::Base.transaction do
      contact = find_or_build_contact(row)
      contact.save!
      link_to_matching_company(contact, row, row_number)
    end
    @processed += 1
  rescue ActiveRecord::RecordInvalid => e
    record_row_error(row_number, e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    record_row_error(row_number, e.message)
  end

  def cell(row, key)
    row[COLUMNS[key]].to_s.strip
  end

  def find_or_build_contact(row)
    contact_data = {
      identifier: cell(row, :identifier),
      name: cell(row, :name),
      email: cell(row, :email),
      phone: cell(row, :phone),
      sector: cell(row, :sector),
    }
    contact = existing_contact(contact_data) || @account.contacts.new
    contact.identifier = contact_data[:identifier] if contact_data[:identifier].present?
    contact.name = contact_data[:name] if contact_data[:name].present?
    contact.email = contact_data[:email].downcase if contact_data[:email].present?
    contact.phone_number = normalized_phone(contact_data[:phone]) if contact_data[:phone].present?
    apply_sector(contact, contact_data)
    contact
  end

  # O ID da planilha (sistema de origem da Ingrid) e a chave mais confiavel
  # entre reimportacoes - e-mail/telefone podem mudar, o ID nao (mesma regra
  # do `ClientesImportJob`).
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

  # Nao existe coluna propria para "setor" no Contact - guarda no
  # additional_attributes (jsonb livre), mesma regra do `ClientesImportJob`.
  def apply_sector(contact, contact_data)
    return if contact_data[:sector].blank?

    contact.additional_attributes = (contact.additional_attributes || {}).merge('setor' => contact_data[:sector])
  end

  # So' vincula quando o nome bate EXATAMENTE (`find_by(name:)` e' sensivel a
  # mai'usculas/minusculas no Postgres) - de proposito, pra nao arriscar
  # vincular no cliente errado so' porque o nome e' parecido. Sem CNPJ na
  # planilha, essa e' a unica forma segura de casar com uma Empresa.
  def link_to_matching_company(contact, row, row_number)
    company_name = cell(row, :company_name)
    return if company_name.blank?

    company = @account.companies.find_by(name: company_name)
    if company.blank?
      record_unmatched_company(row_number, company_name)
      return
    end

    already_linked = CompanyContact.exists?(contact_id: contact.id, company_id: company.id)
    CompanyContact.find_or_create_by!(contact_id: contact.id, company_id: company.id)
    Company.increment_counter(:contacts_count, company.id) unless already_linked
  end

  def record_row_error(row_number, message)
    @failed += 1
    record_log(row_number, 'solicitantes_import_row_error', message)
  end

  # Nao e' uma falha - o contato foi importado normalmente, so' nao achou
  # Empresa com esse Nome Fantasia EXATO pra vincular. Fica registrado no
  # mesmo log de erros da importacao pra dar pra revisar/corrigir sem
  # adivinhar qual contato ficou sem vinculo.
  def record_unmatched_company(row_number, company_name)
    record_log(
      row_number,
      'solicitantes_import_unmatched_company',
      "Nome Fantasia \"#{company_name}\" não encontrado (precisa ser EXATAMENTE igual ao cadastrado no sistema) - " \
      'contato importado sem vínculo com empresa.'
    )
  end

  # `kind: 'row_error'` de proposito (em vez de 'failed'/'skipped') - esses
  # dois valores contam como "skip log" pro `DataImportError` (pensado pro
  # importador do Intercom/Freshdesk) e ficam FORA da contagem de erros e do
  # CSV que o card de importacao mostra; com 'row_error' esses avisos
  # aparecem normalmente pra Ingrid revisar.
  def record_log(row_number, error_code, message)
    @data_import.import_errors.create!(
      error_code: error_code,
      message: message,
      source_object_type: 'row',
      source_object_id: row_number.to_s,
      details: { kind: 'row_error' }
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
