# == Schema Information
#
# Table name: companies
#
#  additional_attributes :jsonb
#  custom_attributes     :jsonb
#  last_activity_at      :datetime
#  id             :bigint           not null, primary key
#  contacts_count :integer
#  description    :text
#  domain         :string
#  name           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_companies_on_account_and_domain   (account_id,domain) UNIQUE WHERE (domain IS NOT NULL)
#  index_companies_on_account_id           (account_id)
#  index_companies_on_name_and_account_id  (name,account_id)
#
class Company < ApplicationRecord
  include Avatarable

  ACTIVITY_ROLLUP_INTERVAL = 5.minutes
  BILLING_TYPES = %w[monthly annual].freeze

  validates :account_id, presence: true
  validates :name, presence: true, length: { maximum: Limits::COMPANY_NAME_LENGTH_LIMIT }
  validates :domain, allow_blank: true, format: {
    with: /\A[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+\z/,
    message: I18n.t('errors.companies.domain.invalid')
  }
  validates :domain, uniqueness: { scope: :account_id }, if: -> { domain.present? }
  validates :description, length: { maximum: Limits::COMPANY_DESCRIPTION_LENGTH_LIMIT }
  validates :custom_attributes, jsonb_attributes_length: true
  validates :cnpj, uniqueness: { scope: :account_id }, if: -> { cnpj.present? }
  validate :validate_cnpj_checksum, if: -> { cnpj.present? }
  validates :billing_type, inclusion: { in: BILLING_TYPES }, allow_blank: true
  validates :billing_amount, :implementation_fee, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  belongs_to :account
  has_many :contacts, dependent: :nullify
  # Tickets point at the Empresa directly. `nullify` rather than `destroy`:
  # removing a company must never take support history with it.
  has_many :tickets, dependent: :nullify
  has_many :company_credentials, dependent: :destroy
  has_many :company_system_modules, dependent: :destroy
  has_many :system_modules, through: :company_system_modules
  before_validation :prepare_jsonb_attributes
  before_validation :normalize_cnpj
  after_create_commit :fetch_favicon, if: -> { domain.present? }
  after_update_commit :enqueue_contact_company_name_sync, if: :saved_change_to_name?

  scope :ordered_by_name, -> { order(:name) }
  scope :search_by_name_or_domain, lambda { |query|
    where('name ILIKE :search OR domain ILIKE :search', search: "%#{query.strip}%")
  }

  scope :order_on_contacts_count, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"companies\".\"contacts_count\" #{direction} NULLS LAST")
      )
    )
  }
  scope :order_on_last_activity_at, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"companies\".\"last_activity_at\" #{direction} NULLS LAST")
      )
    )
  }

  def record_activity_at!(activity_at)
    return if last_activity_at.present? && last_activity_at > activity_at - ACTIVITY_ROLLUP_INTERVAL

    update!(last_activity_at: activity_at)
  end

  private

  CNPJ_FIRST_DIGIT_WEIGHTS = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze
  CNPJ_SECOND_DIGIT_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze

  # Publico e de classe porque a checagem vale fora do cadastro: a triagem das
  # automacoes precisa recusar um CNPJ invalido antes de procurar a empresa, e
  # duas implementacoes da mesma conta acabariam divergindo.
  def self.valid_cnpj?(value)
    digits = value.to_s.gsub(/\D/, '')
    return false unless digits.match?(/\A\d{14}\z/)
    return false if digits.chars.uniq.length == 1

    numbers = digits.chars.map(&:to_i)
    first = cnpj_check_digit(numbers[0..11], CNPJ_FIRST_DIGIT_WEIGHTS)
    second = cnpj_check_digit(numbers[0..11] + [first], CNPJ_SECOND_DIGIT_WEIGHTS)

    numbers[12] == first && numbers[13] == second
  end

  def self.cnpj_check_digit(digits, weights)
    remainder = digits.each_with_index.sum { |digit, index| digit * weights[index] } % 11
    remainder < 2 ? 0 : 11 - remainder
  end

  def prepare_jsonb_attributes
    self.additional_attributes = {} unless additional_attributes.is_a?(Hash)
    self.custom_attributes = {} unless custom_attributes.is_a?(Hash)
  end

  def normalize_cnpj
    self.cnpj = cnpj.gsub(/\D/, '') if cnpj.present?
    self.cnpj = nil if cnpj.blank?
  end

  def validate_cnpj_checksum
    errors.add(:cnpj, :invalid) unless self.class.valid_cnpj?(cnpj)
  end

  def fetch_favicon
    Avatar::AvatarFromFaviconJob.set(wait: 5.seconds).perform_later(self)
  end

  def enqueue_contact_company_name_sync
    Companies::SyncContactNamesJob.perform_later(company_id: id)
  end
end
