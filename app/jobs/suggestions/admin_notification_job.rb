# Em segundo plano: quem enviou a sugestao nao deve esperar a bandeja de todos
# os Administradores ser escrita para receber a confirmacao.
class Suggestions::AdminNotificationJob < ApplicationJob
  queue_as :low

  def perform(suggestion_id)
    suggestion = Suggestion.find_by(id: suggestion_id)
    return if suggestion.blank?

    Suggestions::AdminNotificationBuilder.new(suggestion: suggestion).perform
  end
end
