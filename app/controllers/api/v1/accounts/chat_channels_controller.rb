# As salas do Chat Interno da pessoa logada.
#
# O escopo e o da sessao: ninguem lista, le ou escreve numa sala de que nao
# participa. A excecao e o ADMINISTRADOR, que ve todos os CANAIS da conta -
# canal e da empresa, e quem administra responde por ele. Conversa entre duas
# pessoas continua so de quem participa, para qualquer papel.
class Api::V1::Accounts::ChatChannelsController < Api::V1::Accounts::BaseController
  before_action :fetch_channel, only: [:show, :read, :update, :destroy, :add_member, :remove_member]
  before_action :check_authorization

  def index
    @chat_channels = visible_channels
                     .where(account_id: Current.account.id)
                     .includes(:members, :chat_channel_members)
                     .ordered
                     .to_a
    preload_previews(@chat_channels)
  end

  def show; end

  def create
    @chat_channel = ChatChannel.create!(channel_params.merge(account: Current.account))
    add_members(@chat_channel, member_ids)
    apply_moderators(@chat_channel)
    render 'show'
  end

  # Ajustar o canal depois de criado: tornar fixo, mudar quem pode escrever,
  # renomear. So administrador - sao decisoes sobre o canal da empresa, nao sobre
  # a participacao de cada um nele.
  def update
    return head :forbidden unless administrator?
    return head :forbidden unless @chat_channel.channel?

    @chat_channel.update!(channel_update_params)
    apply_moderators(@chat_channel) if params.key?(:moderator_ids)
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

  def destroy
    @chat_channel.destroy!
    head :ok
  end

  def add_member
    user_id = params[:user_id].to_i
    unless Current.account.user_ids.include?(user_id)
      return render json: { error: 'invalid user' }, status: :unprocessable_entity
    end

    @chat_channel.chat_channel_members.find_or_create_by!(user_id: user_id)
    @chat_channel.reload
    render 'show'
  end

  def remove_member
    @chat_channel.chat_channel_members.where(user_id: params[:user_id]).destroy_all
    @chat_channel.reload
    render 'show'
  end

  private

  # A autorizacao de fato: uma sala fora deste escopo simplesmente nao existe
  # para quem pede.
  def visible_channels
    administrator? ? ChatChannel.visible_to_admin(Current.user) : ChatChannel.for_user(Current.user)
  end

  def administrator?
    Current.account_user&.administrator?
  end

  def fetch_channel
    @chat_channel = visible_channels.find_by!(
      id: params[:id], account_id: Current.account.id
    )
  end

  # Nas acoes de colecao (index/create/direct) nao ha canal ainda para avaliar
  # - a policy recebe a classe. Nas demais, e' o registro de verdade que decide
  # quem pode gerenciar (editar, excluir, adicionar/remover membro).
  def check_authorization(model = nil)
    super(model || @chat_channel || ChatChannel)
  end

  # A previa e o nao lido de todas as salas em duas consultas - a alternativa
  # seria duas por sala, e esta lista abre a cada visita ao Chat.
  def preload_previews(channels)
    ids = channels.map(&:id)
    ultimas = ChatChannel.last_messages_for(ids)
    nao_lidas = ChatChannel.unread_counts_for(Current.user, ids)

    channels.each do |channel|
      channel.last_message = ultimas[channel.id]
      channel.unread_count_for_current = nao_lidas[channel.id]
    end
  end

  # Quem pode escrever num canal de aviso. O administrador escreve sempre, sem
  # precisar de marca; esta lista e para os demais.
  def apply_moderators(channel)
    autorizados = Array(params[:moderator_ids]).map(&:to_i)
    channel.chat_channel_members.each do |member|
      member.update!(can_post: autorizados.include?(member.user_id))
    end
    channel.reload
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

  CHANNEL_FIELDS = [:name, :description, :visibility, :pinned, :posting_policy].freeze

  def channel_params
    params.permit(*CHANNEL_FIELDS)
          .slice(*CHANNEL_FIELDS)
          .merge(kind: :channel, created_by: Current.user)
  end

  # Sem `kind` nem `created_by`: quem criou o canal e o que ele e nao mudam
  # depois.
  def channel_update_params
    params.permit(*CHANNEL_FIELDS).slice(*CHANNEL_FIELDS)
  end
end
