class Checklist < ApplicationRecord
  belongs_to :account
  has_many :project_task_templates, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }

  # Copia todo item deste Checklist pro ticket, continuando a sequencia de
  # `position` depois do que o ticket ja tiver - extraido de
  # Api::V1::Accounts::TicketChecklistItemsController#attach_checklist pra
  # ser reusado tambem no anexo automatico (Team#default_checklist, Modulo de
  # Desenvolvimento) sem duplicar a logica.
  def attach_to!(ticket)
    base_position = ticket.ticket_checklist_items.maximum(:position) || -1

    ActiveRecord::Base.transaction do
      Array(items).filter_map.with_index do |item, index|
        attrs = self.class.item_attributes_from(item)
        next if attrs[:title].blank?

        ticket.ticket_checklist_items.create!(
          attrs.merge(account: ticket.account, position: base_position + index + 1)
        )
      end
    end
  end

  # A Checklist's `items` jsonb array holds plain hashes (string keys, since
  # they round-trip through JSON) - `{ title:, type:, required:, options: }`.
  # `type` is renamed to `item_type` here because `type` on an ActiveRecord
  # attribute is reserved for single-table inheritance.
  def self.item_attributes_from(item)
    item = item.is_a?(Hash) ? item.with_indifferent_access : {}
    {
      title: item[:title].to_s,
      item_type: TicketChecklistItem::ITEM_TYPES.include?(item[:type]) ? item[:type] : 'checkbox',
      required: ActiveModel::Type::Boolean.new.cast(item[:required]) || false,
      options: item[:options].is_a?(Array) ? item[:options] : []
    }
  end
end
