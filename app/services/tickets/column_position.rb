# Where a ticket should sit when it lands in a column without the caller saying
# so - a stage change from the detail page, or a transfer.
#
# Drag-and-drop always sends an explicit drop index and never comes here; every
# other path wants the column to stay ordered by ticket number.
class Tickets::ColumnPosition
  pattr_initialize [:ticket!, :column!]

  # The siblings are renumbered with a gap at the insertion index first:
  # `reindex_column!` sorts by `(position, id)`, so simply reusing an occupied
  # position would lose the tie-break to the older row and land one slot late.
  def by_display_id
    siblings = column.tickets.where.not(id: ticket.id).order(:position, :id).to_a
    index = siblings.count { |sibling| sibling.display_id.to_i < ticket.display_id.to_i }

    siblings.each_with_index do |sibling, order|
      slot = order < index ? order : order + 1
      sibling.update_column(:position, slot) if sibling.position != slot # rubocop:disable Rails/SkipsModelValidations
    end

    index
  end
end
