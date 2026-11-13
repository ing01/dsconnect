# == Schema Information
#
# Table name: client_tutorials
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  position    :integer          default(0), not null
#  title       :string           not null
#  video_url   :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  client_tutorial_module_id :bigint
#
# Indexes
#
#  index_client_tutorials_on_account_id  (account_id)
#  index_client_tutorials_on_client_tutorial_module_id  (client_tutorial_module_id)
#

# Um tutorial da aba "Tutoriais" da Area do Cliente. O video e' um link (YouTube,
# Vimeo ou arquivo) OU um arquivo enviado (mp4/webm) - nunca os dois.
class ClientTutorial < ApplicationRecord
  VIDEO_TYPES = %w[video/mp4 video/webm].freeze
  MAXIMUM_VIDEO_SIZE = 500.megabytes

  belongs_to :account
  # Opcional: sem modulo, o tutorial aparece no card "Geral".
  belongs_to :tutorial_module, class_name: 'ClientTutorialModule', foreign_key: :client_tutorial_module_id,
                               optional: true, inverse_of: :client_tutorials
  has_one_attached :video_file

  validates :title, presence: true, length: { maximum: 200 }
  validates :video_url, format: { with: %r{\Ahttps?://\S+\z}i }, length: { maximum: 500 }, allow_blank: true
  validate :single_video_source
  validate :video_file_acceptable
  validate :module_from_same_account

  scope :ordered, -> { order(:position, :id) }
  scope :visible, -> { where(active: true) }

  def video_file_url
    return nil unless video_file.attached?

    Rails.application.routes.url_helpers.url_for(video_file)
  end

  private

  def module_from_same_account
    return if tutorial_module.blank? || tutorial_module.account_id == account_id

    errors.add(:tutorial_module, :invalid)
  end

  def single_video_source
    return unless video_url.present? && video_file.attached?

    errors.add(:base, I18n.t('client_tutorials.errors.single_source'))
  end

  def video_file_acceptable
    return unless video_file.attached?

    errors.add(:video_file, I18n.t('client_tutorials.errors.video_type')) unless VIDEO_TYPES.include?(video_file.blob.content_type)
    errors.add(:video_file, I18n.t('client_tutorials.errors.video_size')) if video_file.blob.byte_size > MAXIMUM_VIDEO_SIZE
  end
end
