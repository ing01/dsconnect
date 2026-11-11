# O agente avalia uma resposta do DueBot. So da' para avaliar a resposta (nao a
# pergunta, nem o "pensando...") de uma conversa que e' dele.
class Api::V1::Accounts::Captain::CopilotMessageFeedbacksController < Api::V1::Accounts::BaseController
  before_action :set_copilot_message

  # Avaliar de novo atualiza a avaliacao anterior desta pessoa para a mesma resposta.
  def create
    return render json: { error: I18n.t('errors.copilot_feedback.only_assistant') }, status: :unprocessable_entity unless @copilot_message.assistant?

    CopilotMessageFeedback.record!(
      copilot_message: @copilot_message, user: Current.user,
      rating: params[:rating], reason: params[:reason], comment: params[:comment]
    )
    @copilot_message.reload
    render 'api/v1/accounts/captain/copilot_messages/create'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Desfazer: tira a avaliacao desta pessoa e devolve a mensagem sem ela.
  def destroy
    @copilot_message.copilot_message_feedbacks.where(user_id: Current.user.id).destroy_all
    @copilot_message.reload
    render 'api/v1/accounts/captain/copilot_messages/create'
  end

  private

  def set_copilot_message
    thread = Current.account.copilot_threads.find_by!(id: params[:copilot_thread_id], user: Current.user)
    @copilot_message = thread.copilot_messages.find(params[:copilot_message_id])
  end
end
