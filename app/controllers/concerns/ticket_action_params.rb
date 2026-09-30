# Strong parameters and small helpers for the composite ticket actions
# (transfer, create_child, set_parent) plus the origin recorded at creation.
#
# Extracted from TicketsController, which carries a dozen actions of its own.
module TicketActionParams
  extend ActiveSupport::Concern

  private

  # 'manual' unless the ticket is being opened from a chat, in which case the
  # Conversation's channel is the origin. Read before saving, because the
  # Conversation is only linked once the ticket exists.
  def origin_for_creation
    return 'manual' if params[:conversation_id].blank?

    Current.account.conversations.find_by(id: params[:conversation_id])&.inbox&.channel_type || 'manual'
  end

  # Os campos de responsavel de todos os niveis. Gerados, e nao escritos a mao:
  # um nivel novo nao pode depender de alguem lembrar de acrescenta-lo aqui -
  # esquecer fazia o valor chegar na API e ser descartado em silencio.
  ASSIGNEE_PARAMS = AssigneeLeveled::ALL_LEVELS.map { |level| AssigneeLeveled.assignee_column(level) }.freeze

  def transfer_params
    params.require(:ticket).permit(:team_id, :ticket_column_id, :status, :priority, *ASSIGNEE_PARAMS).to_h.symbolize_keys
  end

  # Which parts of the parent to copy server-side. The form is authoritative for
  # every scalar field, so these only drive the copies it cannot express.
  def child_options
    return {} if params[:options].blank?

    params.require(:options).permit(*Tickets::ChildBuilder::COPYABLE).to_h.symbolize_keys
  end

  # The creation form is the same one used everywhere, so a child carries the
  # full set of fields rather than a reduced one.
  def child_attributes
    return {} if params[:ticket].blank?

    params.require(:ticket).permit(
      :title, :description, :priority, :company_id, :contact_id,
      :team_id, :ticket_column_id, :ticket_category_id, :ticket_complexity_id, *ASSIGNEE_PARAMS
    ).to_h.symbolize_keys
  end

  def log_parent_change(previous, parent)
    return if previous&.id == parent&.id

    @ticket.ticket_activities.create!(
      account_id: @ticket.account_id, user: Current.user, activity_type: :parent_changed,
      previous_value: previous&.display_id&.to_s, new_value: parent&.display_id&.to_s,
      meta: { ticket_id: parent&.id }.compact
    )
  end

  def ticket_params
    params.require(:ticket).permit(:title, :description, :priority, :team_id,
                                   :ticket_column_id, :company_id, :contact_id, :ticket_category_id,
                                   :ticket_complexity_id,
                                   :parent_id, :project_id, :due_date, :scheduled_at, :next_project_stage,
                                   *ASSIGNEE_PARAMS, follower_ids: [])
  end
end
