# == Schema Information
#
# Table name: client_tutorial_modules
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  name        :string           not null
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_client_tutorial_modules_on_account_id  (account_id)
#

# Um "modulo" da aba Tutoriais da Area do Cliente (ex.: DS Connect, DS Comercial):
# agrupa os videos e aparece para o cliente como um card.
class ClientTutorialModule < ApplicationRecord
  # SVG fica de fora: pode carregar script. O logo e' so' uma imagem de card.
  LOGO_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAXIMUM_LOGO_SIZE = 5.megabytes

  belongs_to :account
  # Excluir o modulo NAO apaga os videos: eles voltam para o card "Geral".
  has_many :client_tutorials, dependent: :nullify, inverse_of: :tutorial_module
  has_one_attached :logo

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 500 }
  validate :logo_acceptable

  scope :ordered, -> { order(:position, :id) }
  scope :visible, -> { where(active: true) }

  def logo_url
    return nil unless logo.attached?

    Rails.application.routes.url_helpers.url_for(logo)
  end

  private

  def logo_acceptable
    return unless logo.attached?

    errors.add(:logo, I18n.t('client_tutorials.errors.logo_type')) unless LOGO_TYPES.include?(logo.blob.content_type)
    errors.add(:logo, I18n.t('client_tutorials.errors.logo_size')) if logo.blob.byte_size > MAXIMUM_LOGO_SIZE
  end
end
