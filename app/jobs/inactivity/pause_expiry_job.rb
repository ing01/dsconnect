# Encerra as conversas pausadas por inatividade cujo prazo (inclusive
# estendido) acabou sem o cliente voltar.
class Inactivity::PauseExpiryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Conversation.where(status: :snoozed)
                .where("(additional_attributes ->> 'pause_deadline') IS NOT NULL")
                .where("(additional_attributes ->> 'pause_deadline')::timestamptz <= ?", Time.current)
                .find_each do |conversation|
      finalize(conversation)
    end
  end

  private

  def finalize(conversation)
    Inactivity::PauseService.for_paused(conversation)&.finalize!
  rescue StandardError => e
    # Uma conversa com problema nao trava as outras; e' tentada de novo na proxima rodada.
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
  end
end
