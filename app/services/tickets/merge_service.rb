# "Agrupar ticket": the ticket being viewed survives, the selected one is closed
# into it.
#
# Nothing is moved. The merged ticket keeps its comments, attachments, activities
# and linked conversations exactly where they are - the `merged_into` relation is
# what keeps them reachable from the surviving ticket. Copying them would
# duplicate customer messages and destroy the audit trail's meaning.
class Tickets::MergeService
  pattr_initialize [:target!, :source!, :user!]

  def perform
    validate!

    ActiveRecord::Base.transaction do
      source.update!(merged_into: target)
      # Closed rather than a new global status: `close_reason` says why, which is
      # what distinguishes this from an ordinary close.
      #
      # Grouping is an administrative close, not a finished attendance, so it
      # deliberately bypasses the catalogue/communication requirements - the
      # surviving ticket is the one that has to be classified and answered.
      source.close!(user, skip_requirements: true)
      source.update!(close_reason: 'merged')
      log_activities
    end

    target.reload
  end

  private

  def validate!
    raise ArgumentError, I18n.t('tickets.merge.same_ticket') if source.id == target.id
    raise ArgumentError, I18n.t('tickets.merge.already_merged') if source.merged_into_id.present?
    # Without this, A merged into B merged into A would leave two tickets each
    # pointing at the other as the survivor.
    raise ArgumentError, I18n.t('tickets.merge.circular') if target.merged_into_id == source.id
  end

  def log_activities
    target.ticket_activities.create!(
      account_id: target.account_id, user: user, activity_type: :merged_ticket,
      new_value: source.display_id.to_s, meta: { ticket_id: source.id }
    )
    source.ticket_activities.create!(
      account_id: source.account_id, user: user, activity_type: :merged_into,
      new_value: target.display_id.to_s, meta: { ticket_id: target.id }
    )
  end
end
