# As mensagens de uma sala do Chat Interno.
#
# A sala e sempre buscada dentro das salas da pessoa logada, entao nao existe
# caminho para ler ou escrever num lugar de que ela nao participa.
class Api::V1::Accounts::ChatMessagesController < Api::V1::Accounts::BaseController
  MESSAGES_PER_PAGE = 50

  before_action :fetch_channel
  before_action :check_authorization
  before_action :fetch_message, only: [:toggle_reaction, :destroy]

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
    # Num canal de aviso todos leem e so quem foi autorizado escreve. A recusa
    # vem daqui, e nao so da tela: a tela esconder o campo e conveniencia, nunca
    # a regra.
    unless @chat_channel.postable_by?(Current.user, administrator: administrator?)
      return render json: { error: I18n.t('errors.chat_message.not_allowed_to_post') }, status: :forbidden
    end

    @chat_message = @chat_channel.chat_messages.new(
      user: Current.user,
      content: params[:content],
      reply_to: reply_to
    )
    # Os arquivos ja subiram direto para o storage; o que chega aqui sao os
    # signed ids dos blobs, nunca os bytes.
    @chat_message.attachments.attach(attachment_blobs) if attachment_blobs.any?
    @chat_message.save!
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
    # Quem esta com a sala aberta ve a reacao sem recarregar.
    @chat_message.dispatch_updated_event
    render 'show'
  end

  # Apagar uma mensagem. O autor apaga a propria; o administrador apaga qualquer
  # uma, porque e quem responde pelo que fica no Chat da empresa.
  #
  # Apaga de verdade, em vez de marcar como apagada: o pedido e tirar a mensagem
  # do Chat, e um rastro "mensagem apagada" continuaria mostrando que algo foi
  # dito. As RESPOSTAS a ela sobrevivem, so perdem a citacao (ChatMessage#replies).
  def destroy
    unless @chat_message.deletable_by?(Current.user, administrator: administrator?)
      return render json: { error: I18n.t('errors.chat_message.not_allowed_to_delete') }, status: :forbidden
    end

    @chat_message.destroy!
    head :ok
  end

  private

  def administrator?
    Current.account_user&.administrator?
  end

  # Aceita um ou varios, e ignora entrada vazia para o cliente nao precisar
  # decidir entre mandar lista vazia ou nao mandar nada.
  def attachment_blobs
    @attachment_blobs ||= Array(params[:attachments]).compact_blank
  end

  # Mesmo escopo da listagem de salas: o administrador alcanca todos os canais da
  # conta, e as conversas seguem sendo de quem participa.
  def fetch_channel
    escopo = administrator? ? ChatChannel.visible_to_admin(Current.user) : ChatChannel.for_user(Current.user)
    @chat_channel = escopo.find_by!(
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
