# == Schema Information
#
# Table name: data_imports
#
#  id                :bigint           not null, primary key
#  abandoned_at      :datetime
#  access_token      :text
#  completed_at      :datetime
#  cursor            :jsonb            not null
#  data_type         :string           not null
#  import_types      :jsonb            not null
#  last_error_at     :datetime
#  name              :string
#  processed_records :integer
#  processing_errors :text
#  source_metadata   :jsonb            not null
#  source_provider   :string
#  source_type       :string
#  started_at        :datetime
#  stats             :jsonb            not null
#  status            :integer          default("pending"), not null
#  total_records     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  initiated_by_id   :integer
#
# Indexes
#
#  index_data_imports_on_account_id       (account_id)
#  index_data_imports_on_initiated_by_id  (initiated_by_id)
#  index_data_imports_on_source_provider  (source_provider)
#
class DataImport < ApplicationRecord
  ACTIVE_IMPORT_RUN_ID_KEY = 'active_import_run_id'.freeze
  ACTIVE_INTERCOM_IMPORT_RUN_ID_KEY = 'active_intercom_import_run_id'.freeze
  IMPORT_STALLED_AFTER = 15.minutes
  INTERCOM_STALLED_AFTER = IMPORT_STALLED_AFTER
  LEGACY_DATA_TYPES = %w[contacts clientes solicitantes company_priority company_cnpj_check service_catalog].freeze
  UPLOAD_DATA_TYPES = %w[clientes solicitantes company_priority company_cnpj_check service_catalog].freeze
  INTEGRATION_DATA_TYPES = %w[freshdesk intercom].freeze
  IMPORT_TYPES = %w[contacts conversations].freeze

  belongs_to :account
  belongs_to :initiated_by, class_name: 'User', optional: true

  encrypts :access_token if Chatwoot.encryption_configured?

  has_many :items, class_name: 'DataImportItem', dependent: :destroy_async
  has_many :mappings, class_name: 'DataImportMapping', dependent: :destroy_async
  has_many :import_errors, class_name: 'DataImportError', dependent: :destroy_async

  validates :data_type, inclusion: { in: LEGACY_DATA_TYPES + INTEGRATION_DATA_TYPES, message: I18n.t('errors.data_import.data_type.invalid') }
  validates :access_token, presence: true, on: :create, if: :integration_import?
  validate :validate_import_types
  validate :validate_integration_provider

  enum status: { pending: 0, processing: 1, completed: 2, failed: 3, completed_with_errors: 6, abandoned: 7 }

  scope :active_intercom, -> { where(data_type: 'intercom', source_provider: 'intercom', status: [:pending, :processing]) }
  scope :active_integrations, lambda {
    where(data_type: INTEGRATION_DATA_TYPES, status: [:pending, :processing]).where('source_provider = data_type')
  }

  has_one_attached :import_file
  has_one_attached :failed_records

  before_validation :set_default_name, on: :create
  after_create_commit :process_data_import

  def legacy_contacts_csv_import?
    data_type == 'contacts' && source_provider.blank?
  end

  def clientes_import?
    data_type == 'clientes' && source_provider.blank?
  end

  # Importacao de Contatos/Solicitantes - igual a `clientes_import?` mas sem
  # CNPJ: cada linha e' um contato, e o vinculo com Empresa (quando a
  # planilha trouxer o Nome Fantasia) so' acontece se o nome bater EXATAMENTE
  # com uma Empresa ja cadastrada (ver `SolicitantesImportJob`).
  def solicitantes_import?
    data_type == 'solicitantes' && source_provider.blank?
  end

  # Segunda opcao de importacao de Empresa - so Codigo/CNPJ/Prioridade,
  # separada da importacao "Clientes" (que tambem traz nome, endereco e
  # contatos). So ATUALIZA empresa ja existente (casa por Codigo ou CNPJ);
  # a planilha nao tem "Nome", entao nao da pra criar uma empresa nova aqui.
  def company_priority_import?
    data_type == 'company_priority' && source_provider.blank?
  end

  # Nao grava nada - so compara os CNPJs da planilha contra as empresas ja
  # cadastradas na conta e devolve, por linha, se ja existe ou nao (ver
  # `CompanyCnpjCheckJob`).
  def company_cnpj_check_import?
    data_type == 'company_cnpj_check' && source_provider.blank?
  end

  def service_catalog_import?
    data_type == 'service_catalog' && source_provider.blank?
  end

  def intercom_import?
    data_type == 'intercom' && source_provider == 'intercom'
  end

  def freshdesk_import?
    data_type == 'freshdesk' && source_provider == 'freshdesk'
  end

  def integration_import?
    INTEGRATION_DATA_TYPES.include?(data_type) && data_type == source_provider
  end

  def restartable?
    failed? || abandoned?
  end

  def stalled?
    integration_import? && (pending? || processing?) && updated_at <= IMPORT_STALLED_AFTER.ago
  end

  def abandonable?
    integration_import? && (pending? || processing?)
  end

  def abandon!
    self.class.transaction do
      active_imports = self.class.lock.where(id: id, data_type: INTEGRATION_DATA_TYPES, status: [:pending, :processing])
      abandonable_import = active_imports.where('source_provider = data_type').first
      abandonable_import&.update!(status: :abandoned, abandoned_at: Time.current)
    end
    reload
  end

  def active_intercom_import_run_id
    active_import_run_id
  end

  def assign_active_intercom_import_run_id
    assign_active_import_run_id
  end

  def active_import_run_id
    source_metadata.to_h[ACTIVE_IMPORT_RUN_ID_KEY] || source_metadata.to_h[ACTIVE_INTERCOM_IMPORT_RUN_ID_KEY]
  end

  def assign_active_import_run_id
    run_id = SecureRandom.uuid
    self.source_metadata = source_metadata.to_h.merge(ACTIVE_IMPORT_RUN_ID_KEY => run_id)
    source_metadata[ACTIVE_INTERCOM_IMPORT_RUN_ID_KEY] = run_id if intercom_import?
    run_id
  end

  private

  def set_default_name
    return if name.present? || data_type.blank?

    self.name = "#{data_type.titleize} - #{Date.current.iso8601}"
  end

  def process_data_import
    # we wait for the file to be uploaded to the cloud
    return DataImportJob.set(wait: 1.minute).perform_later(self) if legacy_contacts_csv_import?
    return ClientesImportJob.set(wait: 1.minute).perform_later(self) if clientes_import?
    return SolicitantesImportJob.set(wait: 1.minute).perform_later(self) if solicitantes_import?
    return CompanyPriorityImportJob.set(wait: 1.minute).perform_later(self) if company_priority_import?
    return CompanyCnpjCheckJob.set(wait: 1.minute).perform_later(self) if company_cnpj_check_import?
    return ServiceCatalogImportJob.set(wait: 1.minute).perform_later(self) if service_catalog_import?
  end

  def validate_import_types
    return if import_types.blank?

    invalid_types = import_types - IMPORT_TYPES
    return if invalid_types.blank?

    errors.add(:import_types, "contains unsupported values: #{invalid_types.join(', ')}")
  end

  def validate_integration_provider
    return unless INTEGRATION_DATA_TYPES.include?(data_type)
    return if source_provider == data_type

    errors.add(:source_provider, 'must match the integration data type')
  end
end
