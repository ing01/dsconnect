class Api::V1::Accounts::Captain::CopilotThreadsController < Api::V1::Accounts::BaseController
  include Captain::Copilot::ConversationAccess

  before_action :ensure_message, only: :create
  before_action :ensure_accessible_conversation, only: :create

  def index
    @copilot_threads = Current.account.copilot_threads
                              .where(user_id: Current.user.id)
                              .includes(:user, :assistant)
                              .order(created_at: :desc)
                              .page(permitted_params[:page] || 1)
                              .per(20)
  end

  def create
    ActiveRecord::Base.transaction do
      @copilot_thread = Current.account.copilot_threads.create!(
        title: copilot_thread_params[:message],
        user: Current.user,
        assistant: assistant,
        conversation_display_id: context_conversation&.display_id,
        ticket_id: context_ticket&.id,
        screen: context_screen
      )

      copilot_message = @copilot_thread.copilot_messages.create!(
        message_type: :user,
        message: { content: copilot_thread_params[:message] }
      )

      build_copilot_response(copilot_message)
    end
  end

  # So' o historico da propria pessoa: a conversa de outro usuario nem e'
  # encontrada. As mensagens saem junto (dependent: :destroy_async).
  def destroy
    Current.account.copilot_threads.find_by!(id: params[:id], user_id: Current.user.id).destroy!
    head :ok
  end

  private

  def build_copilot_response(copilot_message)
    if Current.account.usage_limits[:captain][:responses][:current_available].positive?
      enqueue_copilot_response(copilot_message)
    else
      copilot_message.copilot_thread.copilot_messages.create!(
        message_type: :assistant,
        message: { content: I18n.t('captain.copilot_limit') }
      )
    end
  end

  def enqueue_copilot_response(copilot_message)
    return enqueue_reply_suggestion if reply_suggestion?

    copilot_message.enqueue_response_job(copilot_thread_params[:conversation_id], Current.user.id)
  end

  def enqueue_reply_suggestion
    Captain::Copilot::ReplySuggestionJob.perform_later(
      assistant: @copilot_thread.assistant,
      conversation_id: copilot_thread_params[:conversation_id],
      user_id: Current.user.id,
      copilot_thread_id: @copilot_thread.id
    )
  end

  # Onde o chat foi aberto. Basta existir na conta: e' so' o numero do link de
  # volta, e quem abre o link continua passando pela permissao normal da tela.
  # (Nao usa `accessible_conversation`: ele so' enxerga conversas de inbox/time
  # da pessoa, e o agente que abriu a conversa por outro caminho - atribuida a
  # ele, por exemplo - ficava sem origem.)
  def context_conversation
    return if copilot_thread_params[:conversation_id].blank?

    @context_conversation ||= Current.account.conversations.find_by(display_id: copilot_thread_params[:conversation_id])
  end

  # A tela so' conta quando o chat nao foi aberto numa conversa nem num ticket.
  # E' o nome da rota do front: so' letras minusculas, numeros e "_".
  def context_screen
    return if context_conversation || context_ticket

    name = copilot_thread_params[:screen].to_s.strip
    name.match?(/\A[a-z0-9_]{1,100}\z/) ? name : nil
  end

  def context_ticket
    return if copilot_thread_params[:ticket_id].blank?

    @context_ticket ||= Current.account.tickets.find_by(id: copilot_thread_params[:ticket_id])
  end

  def ensure_message
    return render_could_not_create_error(I18n.t('captain.copilot_message_required')) if copilot_thread_params[:message].blank?
  end

  def ensure_accessible_conversation
    return unless reply_suggestion?

    conversation = accessible_conversation(
      account: Current.account,
      user: Current.user,
      display_id: copilot_thread_params[:conversation_id]
    )
    raise ActiveRecord::RecordNotFound, 'Conversation not found' if conversation.blank?
  end

  def reply_suggestion?
    copilot_thread_params[:request_type] == 'reply_suggestion'
  end

  def assistant
    Current.account.captain_assistants.find(copilot_thread_params[:assistant_id])
  end

  def copilot_thread_params
    params.permit(:message, :assistant_id, :conversation_id, :ticket_id, :screen, :request_type)
  end

  def permitted_params
    params.permit(:page)
  end
end
