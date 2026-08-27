module QueueActivityMessageHandler
  extend ActiveSupport::Concern

  private

  def create_queue_change_activity(user_name)
    user_name = activity_message_owner(user_name)
    return unless user_name

    key = generate_queue_change_activity_key
    params = { queue_name: queue&.name, user_name: user_name }
    params[:queue_name] = generate_queue_name_for_activity if key == 'removed'
    content = I18n.t("conversations.activity.queue.#{key}", **params)

    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content)) if content
  end

  def generate_queue_change_activity_key
    ServiceQueue.find_by(id: queue_id).present? ? 'assigned' : 'removed'
  end

  def generate_queue_name_for_activity
    previous_queue_id = previous_changes[:queue_id][0]
    ServiceQueue.find_by(id: previous_queue_id)&.name if previous_queue_id.present?
  end
end
