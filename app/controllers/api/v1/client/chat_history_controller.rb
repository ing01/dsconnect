# O historico do chat: sessoes ANTERIORES (resolvidas) - a conversa "de
# agora" fica em `ChatsController`. Somente leitura: um encerramento e'
# definitivo aqui, sem reabrir ou responder por esta tela.
class Api::V1::Client::ChatHistoryController < Api::V1::Client::BaseController
  LIMIT = 50

  def index
    @conversations = past_conversations.includes(:messages).order(created_at: :desc).limit(LIMIT)
  end

  def show
    @conversation = past_conversations.find_by!(display_id: params[:id])
  end

  private

  def past_conversations
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(Current.account)
    return Conversation.none if inbox.blank?

    Current.account.conversations.where(inbox_id: inbox.id, contact_id: current_contact.id, status: :resolved)
  end
end
