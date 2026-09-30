# Uma mensagem do cliente no chat com a equipe.
#
# Mesmo molde do Website Widget: `conversation.messages.create!` com
# `message_type: :incoming` e o CONTATO como remetente - e o que dispara os
# eventos normais (`message_created`) que alimentam a automacao de triagem e
# a tela de Conversas do atendente em tempo real, sem nada de especial aqui.
class Api::V1::Client::ChatMessagesController < Api::V1::Client::BaseController
  before_action :fetch_conversation

  def create
    return render_empty_message if params[:content].to_s.strip.blank?

    @message = @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      sender: current_contact,
      content: params[:content].to_s.strip,
      message_type: :incoming
    )

    render 'api/v1/client/chats/message', status: :created
  end

  private

  # A mensagem so pode entrar numa conversa que ja existe - `show` do chat cria
  # na primeira vez. Sem isso, chamar direto o `create` sem nunca ter aberto a
  # tela do chat respondia com um NoMethodError, e nao um erro claro.
  def fetch_conversation
    inbox = ::Inboxes::EnsureClientPortalInboxService.new(account: Current.account).perform
    @conversation = Current.account.conversations.find_by(inbox_id: inbox.id, contact_id: current_contact.id)
    render_conversation_missing if @conversation.nil?
  end

  def render_conversation_missing
    render json: { error: I18n.t('client_area.chat.not_started') }, status: :unprocessable_entity
  end

  def render_empty_message
    render json: { error: I18n.t('client_area.chat.empty'), code: 'content_required' }, status: :unprocessable_entity
  end
end
