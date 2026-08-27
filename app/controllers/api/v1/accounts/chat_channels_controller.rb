# As salas do Chat Interno da pessoa logada.
#
# Sempre no escopo do usuario da sessao: ninguem lista, le ou escreve numa sala
# de que nao participa. Um canal publico so aparece depois que a pessoa entra
# nele - descobrir canais e assunto de outra etapa.
class Api::V1::Accounts::ChatChannelsController < Api::V1::Accounts::BaseController
  before_action :fetch_channel, only: [:show, :read]
  before_action :check_authorization

  def index
    @chat_channels = ChatChannel.for_user(Current.user)
                                .where(account_id: Current.account.id)
                                .includes(:members, :chat_channel_members)
                                .ordered
  end

  def show; end

  def create
    @chat_channel = ChatChannel.create!(channel_params.merge(account: Current.account))
    add_members(@chat_channel, member_ids)
    render 'show'
  end

  # Abre a conversa com alguem, ou devolve a que ja existe - duas pessoas nunca
  # tem duas conversas privadas entre si.
  def direct
    peer = Current.account.users.find(params[:user_id])
    ids = [Current.user.id, peer.id].uniq

    @chat_channel = ChatChannel.direct_between(Current.account, ids)
    if @chat_channel.blank?
      @chat_channel = ChatChannel.create!(account: Current.account, kind: :direct, created_by: Current.user)
      add_members(@chat_channel, ids)
    end

    render 'show'
  end

  def read
    membership(@chat_channel)&.mark_read!
    head :ok
  end

  private

  def fetch_channel
    # `for_user` e a autorizacao de fato: uma sala de que a pessoa nao participa
    # simplesmente nao existe para ela.
    @chat_channel = ChatChannel.for_user(Current.user).find_by!(
      id: params[:id], account_id: Current.account.id
    )
  end

  def membership(channel)
    channel.chat_channel_members.find_by(user_id: Current.user.id)
  end

  # Quem cria entra junto: um canal sem o autor seria um canal que ele nao ve.
  def add_members(channel, ids)
    ([Current.user.id] + ids).uniq.each do |user_id|
      channel.chat_channel_members.find_or_create_by!(user_id: user_id)
    end
    channel.reload
  end

  def member_ids
    Array(params[:member_ids]).map(&:to_i) & Current.account.user_ids
  end

  def channel_params
    params.permit(:name, :description, :visibility)
          .slice(:name, :description, :visibility)
          .merge(kind: :channel, created_by: Current.user)
  end
end
