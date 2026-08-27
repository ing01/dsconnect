# As mensagens de uma sala do Chat Interno.
#
# A sala e sempre buscada dentro das salas da pessoa logada, entao nao existe
# caminho para ler ou escrever num lugar de que ela nao participa.
class Api::V1::Accounts::ChatMessagesController < Api::V1::Accounts::BaseController
  MESSAGES_PER_PAGE = 50

  before_action :fetch_channel
  before_action :check_authorization
  before_action :fetch_message, only: [:toggle_reaction]

  def index
    scope = @chat_channel.chat_messages.includes(:user, :chat_message_reactions, :reply_to)
    # Pagina para tras a partir de uma mensagem: e assim que se sobe o
    # historico sem carregar a sala inteira.
    scope = scope.where(chat_messages: { id: ...params[:before].to_i }) if params[:before].present?

    # As mais recentes primeiro na consulta, mas entregues em ordem de leitura.
    @chat_messages = scope.order(created_at: :desc, id: :desc)
                          .limit(MESSAGES_PER_PAGE)
                          .to_a
                          .reverse
  end

  def create
    @chat_message = @chat_channel.chat_messages.create!(
      user: Current.user,
      content: params[:content],
      reply_to: reply_to
    )
    # Quem escreve leu tudo o que veio antes.
    membership&.mark_read!
    render 'show'
  end

  # Reagir e desreagir sao o mesmo gesto: clicar de novo no mesmo emoji tira a
  # reacao.
  def toggle_reaction
    reaction = @chat_message.chat_message_reactions
                            .find_by(user_id: Current.user.id, emoji: params[:emoji])

    if reaction
      reaction.destroy!
    else
      @chat_message.chat_message_reactions.create!(user: Current.user, emoji: params[:emoji])
    end

    @chat_message.reload
    render 'show'
  end

  private

  def fetch_channel
    @chat_channel = ChatChannel.for_user(Current.user).find_by!(
      id: params[:chat_channel_id], account_id: Current.account.id
    )
  end

  def fetch_message
    @chat_message = @chat_channel.chat_messages.find(params[:id])
  end

  def membership
    @chat_channel.chat_channel_members.find_by(user_id: Current.user.id)
  end

  # Responder so vale dentro da mesma sala.
  def reply_to
    return if params[:reply_to_id].blank?

    @chat_channel.chat_messages.find_by(id: params[:reply_to_id])
  end

  # A autorizacao real e a participacao na sala, ja garantida por `fetch_channel`.
  def check_authorization
    authorize(@chat_channel, :show?)
  end
end
