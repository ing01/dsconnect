# Ticket-to-ticket relations: parent/child ("Criar ticket filho", "Referenciar
# ticket pai") and grouping ("Agrupar ticket").
#
# Kept out of Ticket itself because the cycle guard is a self-contained problem
# that has nothing to do with the rest of the ticket's lifecycle.
module TicketRelatable
  extend ActiveSupport::Concern

  # A pre-existing loop in the data must not hang the ancestry walk.
  MAXIMUM_ANCESTRY_DEPTH = 50

  included do
    # A ticket has at most one parent (the relation is replaced, not
    # accumulated, when a new one is referenced) and any number of children.
    # `nullify` rather than `cascade`: deleting a parent must never take its
    # children's history with it.
    belongs_to :parent, class_name: 'Ticket', optional: true
    has_many :children, class_name: 'Ticket', foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent

    # Grouping. `merged_into` is the surviving ticket; `merged_tickets` are the
    # ones closed into this one. Nothing is copied - the relation is what keeps
    # the merged ticket's content reachable.
    belongs_to :merged_into, class_name: 'Ticket', optional: true
    has_many :merged_tickets, class_name: 'Ticket', foreign_key: :merged_into_id, dependent: :nullify,
                              inverse_of: :merged_into

    validate :parent_is_not_self_or_ancestor
    validate :merge_target_is_not_self
  end

  private

  # A ticket cannot be its own parent, and no chain of parents may loop back to
  # it (A -> B -> C -> A). Enforced in the model rather than only in the UI,
  # since the API accepts a parent directly.
  def parent_is_not_self_or_ancestor
    return if parent_id.blank?

    return errors.add(:parent, :invalid) if parent_id == id

    errors.add(:parent, :invalid) if descendant_ids.include?(parent_id)
  end

  def descendant_ids
    ids = []
    frontier = [id].compact
    MAXIMUM_ANCESTRY_DEPTH.times do
      break if frontier.empty?

      frontier = Ticket.where(parent_id: frontier).where.not(id: ids).pluck(:id)
      ids.concat(frontier)
    end
    ids
  end

  def merge_target_is_not_self
    errors.add(:merged_into, :invalid) if merged_into_id.present? && merged_into_id == id
  end
end
