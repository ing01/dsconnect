require 'roo'

# Imports the "Catálogo de Serviços" spreadsheet from the Dados screen.
# Populates the existing 3-level tree (ServiceCatalog > ServiceCatalogArea >
# ServiceCatalogItem) - see app/models/service_catalog*.rb. Each level is
# find_or_create'd, so re-importing the same sheet is safe and only adds
# what's missing.
class ServiceCatalogImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  COLUMNS = {
    catalog: 'Catálogo',
    area: 'Área',
    item: 'Item',
  }.freeze

  def perform(data_import)
    @data_import = data_import
    @account = data_import.account
    @processed = 0
    @failed = 0
    @catalog_cache = {}
    @area_cache = {}

    @data_import.update!(status: :processing)
    process_rows
    @data_import.update!(status: :completed, processed_records: @processed, total_records: @processed + @failed)
  rescue StandardError => e
    @data_import.update!(status: :failed)
    Rails.logger.error("[ServiceCatalogImportJob] #{e.class}: #{e.message}")
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
    catalog_name = row[COLUMNS[:catalog]].to_s.strip
    area_name = row[COLUMNS[:area]].to_s.strip
    item_name = row[COLUMNS[:item]].to_s.strip

    if catalog_name.blank? || area_name.blank? || item_name.blank?
      record_error(row_number, 'Catálogo, Área e Item são obrigatórios')
      return
    end

    catalog = find_or_create_catalog(catalog_name)
    area = find_or_create_area(catalog, area_name)
    area.service_catalog_items.find_or_create_by!(name: item_name)
    @processed += 1
  rescue ActiveRecord::RecordInvalid => e
    record_error(row_number, e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    record_error(row_number, e.message)
  end

  def find_or_create_catalog(name)
    @catalog_cache[name] ||= @account.service_catalogs.find_or_create_by!(name: name)
  end

  def find_or_create_area(catalog, name)
    @area_cache[[catalog.id, name]] ||= catalog.service_catalog_areas.find_or_create_by!(name: name)
  end

  def record_error(row_number, message)
    @failed += 1
    @data_import.import_errors.create!(
      error_code: 'service_catalog_import_row_error',
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
