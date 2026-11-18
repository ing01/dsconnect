# == Schema Information
#
# Table name: client_announcements
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  audience              :string           default("all"), not null
#  body                  :text
#  classification_levels :integer          default([]), not null, is an Array
#  company_ids           :bigint           default([]), not null, is an Array
#  company_niche_ids     :bigint           default([]), not null, is an Array
#  company_sub_niche_ids :bigint           default([]), not null, is an Array
#  ends_at               :datetime
#  kind                  :string           default("info"), not null
#  link_label            :string
#  link_url              :string
#  position              :integer          default(0), not null
#  starts_at             :datetime
#  title                 :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  created_by_id         :bigint
#
# Indexes
#
#  index_client_announcements_on_account_id      (account_id)
#  index_client_announcements_on_account_window  (account_id,active,starts_at,ends_at)
#  index_client_announcements_on_created_by_id   (created_by_id)
#

# Um aviso do "Mural de Avisos" do Portal do Cliente. Dentro da janela
# (`starts_at`..`ends_at`) ele aparece no Principal e abre em modal a cada login,
# para o cliente fechar antes de seguir. O texto e' simples (sem HTML): o Portal
# o renderiza como texto, com quebras de linha.
class ClientAnnouncement < ApplicationRecord
  KINDS = %w[info warning success urgent].freeze
  AUDIENCES = %w[all segmented].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 5000 }
  validates :kind, inclusion: { in: KINDS }
  validates :audience, inclusion: { in: AUDIENCES }
  validates :link_url, format: { with: %r{\Ahttps?://\S+\z}i }, length: { maximum: 500 }, allow_blank: true
  validates :link_label, length: { maximum: 60 }
  validate :window_in_order
  validate :segmentation_present

  before_validation :normalize_lists

  scope :ordered, -> { order(:position, :id) }
  scope :visible, -> { where(active: true) }
  scope :in_window, lambda { |now = Time.current|
    where('starts_at IS NULL OR starts_at <= ?', now).where('ends_at IS NULL OR ends_at > ?', now)
  }
  scope :currently_visible, ->(now = Time.current) { visible.in_window(now) }

  # Urgente primeiro, depois a ordem escolhida pelo administrador.
  def self.for_display
    all.sort_by { |announcement| [announcement.kind == 'urgent' ? 0 : 1, announcement.position, announcement.id] }
  end

  def segmented?
    audience == 'segmented'
  end

  # Estado mostrado ao administrador na lista.
  def status(now = Time.current)
    return :inactive unless active
    return :scheduled if starts_at && starts_at > now
    return :expired if ends_at && ends_at <= now

    :live
  end

  # `companies`: as Empresas do contato logado. Sem segmentacao, todos veem.
  def visible_to?(companies)
    return true unless segmented?

    Array(companies).any? { |company| matches_company?(company) }
  end

  private

  def matches_company?(company)
    dimension_match?(company_ids, company.id) &&
      dimension_match?(company_niche_ids, company.company_niche_id) &&
      dimension_match?(company_sub_niche_ids, company.company_sub_niche_id) &&
      dimension_match?(classification_levels, company.classification_level)
  end

  def dimension_match?(allowed, value)
    allowed.blank? || allowed.include?(value)
  end

  def normalize_lists
    self.company_ids = Array(company_ids).map(&:to_i).uniq
    self.company_niche_ids = Array(company_niche_ids).map(&:to_i).uniq
    self.company_sub_niche_ids = Array(company_sub_niche_ids).map(&:to_i).uniq
    self.classification_levels = Array(classification_levels).map(&:to_i).uniq
    self.link_label = nil if link_url.blank?
  end

  def window_in_order
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, I18n.t('client_announcements.errors.ends_before_start'))
  end

  # "Segmentado" sem nenhum filtro nao teria publico nenhum: e' erro, nao um aviso invisivel.
  def segmentation_present
    return unless segmented?
    return if [company_ids, company_niche_ids, company_sub_niche_ids, classification_levels].any?(&:present?)

    errors.add(:audience, I18n.t('client_announcements.errors.segmentation_empty'))
  end
end
