# Em segundo plano - a conta pode ter varios colaboradores, e quem publicou o
# artigo ou criou o portal nao deve esperar a bandeja de todo mundo ser
# escrita pra seguir em frente (mesmo motivo de Suggestions::AdminNotificationJob).
class HelpCenter::ContentNotificationJob < ApplicationJob
  queue_as :low

  def perform(content_type, content_id, notification_type, exclude_user_id = nil)
    content = content_type.constantize.find_by(id: content_id)
    return if content.blank?

    HelpCenter::ContentNotificationBuilder.new(
      content: content,
      notification_type: notification_type,
      exclude_user_id: exclude_user_id
    ).perform
  end
end
