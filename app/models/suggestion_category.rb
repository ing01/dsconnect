# == Schema Information
#
# Table name: suggestion_categories
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_suggestion_categories_on_account_id  (account_id)
#

# Lista de categorias do quadro de Sugestoes, configuravel por conta - mesma
# logica de SuggestionPriority.
class SuggestionCategory < ApplicationRecord
  belongs_to :account
  has_many :suggestions, foreign_key: :category_id, dependent: :nullify, inverse_of: :category

  validates :name, presence: true

  before_validation :set_default_position, on: :create

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (account&.suggestion_categories&.maximum(:position) || -1) + 1
  end
end
