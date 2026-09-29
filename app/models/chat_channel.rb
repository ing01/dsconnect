# Uma sala do Chat Interno: um canal da empresa ou uma conversa entre duas
# pessoas. As duas coisas tem membros, mensagens e leitura por pessoa, entao
# vivem no mesmo modelo e mudam apenas de `kind`.
#
# Nada aqui se comunica com clientes. Conversation e outra coisa - atendimento,
# com inbox, contato, SLA e relatorios - e as duas nunca se cruzam.
class ChatChannel < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :chat_channel_members, dependent: :destroy
  has_many :members, through: :chat_channel_members, source: :user
  has_many :chat_messages, dependent: :destroy

  enum kind: { channel: 0, direct: 1 }
  enum visibility: { public_channel: 0, private_channel: 1 }
  # Quem pode ESCREVER. Ler segue sendo participar da sala; isto separa as duas
  # coisas, que e o que um canal de aviso precisa.
  enum posting_policy: { everyone: 0, moderators: 1 }, _prefix: :posting

  validates :name, presence: true, if: :channel?
  validates :name, uniqueness: { scope: :account_id }, if: -> { channel? && name.present? }
  validate :direct_has_no_name

  # Canal fixo primeiro: e onde mora o que todos precisam ver, e a ordem por
  # ultima mensagem o empurrava para baixo sozinho conforme as outras salas se
  # movimentavam.
  scope :ordered, -> { order(pinned: :desc).order(Arel.sql('COALESCE(last_message_at, created_at) DESC')) }
  # As salas de uma pessoa: canais em que ela esta e as conversas dela.
  scope :for_user, lambda { |user|
    where(id: ChatChannelMember.where(user_id: user.id).select(:chat_channel_id))
  }

  # O que o ADMINISTRADOR ve: todos os canais da conta, inclusive os que nao criou
  # e os em que nao entrou, mais as conversas dele.
  #
  # A linha e entre CANAL e CONVERSA, nao entre publico e privado: canal e da
  # empresa, e quem administra responde por ele; conversa entre duas pessoas
  # continua so de quem participa - administrar o Chat nao e ler conversa alheia.
  scope :visible_to_admin, lambda { |user|
    where(kind: :channel).or(for_user(user))
  }

  # A conversa entre duas pessoas, se ja existir. Procurada pelos participantes,
  # porque uma conversa privada nao tem nome que a identifique.
  # Escopado pela conta sem uma associacao em Account: aquele modelo ja esta no
  # limite de tamanho que o projeto mantem, e o Chat nao precisa engorda-lo.
  def self.direct_between(account, user_ids)
    ids = user_ids.uniq.sort
    where(account_id: account.id)
      .direct
      .joins(:chat_channel_members)
      .group('chat_channels.id')
      .having('COUNT(chat_channel_members.id) = ?', ids.size)
      .having('SUM(CASE WHEN chat_channel_members.user_id IN (?) THEN 1 ELSE 0 END) = ?', ids, ids.size)
      .first
  end

  # Quantas mensagens esta pessoa ainda nao viu. Calculado no servidor, e nao no
  # navegador, para que o numero seja o mesmo em qualquer aparelho.
  #
  # A LISTAGEM preenche isto de fora, com uma consulta para todas as salas de uma
  # vez. O sinalizador e separado do valor porque a consulta agrupada NAO devolve
  # linha para sala sem mensagem nova: ali o valor legitimo e zero, e tratar isso
  # como "nao preenchido" jogaria justamente essas salas de volta na consulta por
  # sala.
  def unread_count_for_current=(value)
    @unread_preloaded = true
    @unread_count_for_current = value.to_i
  end

  def unread_count_for(user)
    return @unread_count_for_current if @unread_preloaded

    membership = chat_channel_members.find_by(user_id: user.id)
    return 0 if membership.blank?

    scope = chat_messages.where.not(user_id: user.id)
    scope = scope.where('chat_messages.created_at > ?', membership.last_read_at) if membership.last_read_at
    scope.count
  end

  # A participacao entra na consulta pela juncao para que o corte de leitura de
  # CADA sala (o `last_read_at` dela) caiba numa consulta unica. `%<user_id>d`
  # forca inteiro, entao nao ha como injetar nada aqui.
  UNREAD_JOIN = <<~SQL.squish
    INNER JOIN chat_channel_members
            ON chat_channel_members.chat_channel_id = chat_messages.chat_channel_id
           AND chat_channel_members.user_id = %<user_id>d
  SQL

  # O nao lido de todas as salas numa consulta so.
  #
  # O corte e por sala (cada uma tem o seu `last_read_at`), entao a comparacao
  # entra na juncao com a participacao em vez de virar uma consulta por sala -
  # que era o que esta lista fazia, em toda visita ao Chat.
  def self.unread_counts_for(user, channel_ids)
    return {} if channel_ids.blank?

    ChatMessage
      .joins(format(UNREAD_JOIN, user_id: user.id.to_i))
      .where(chat_channel_id: channel_ids)
      .where.not(chat_messages: { user_id: user.id })
      .where('chat_channel_members.last_read_at IS NULL OR chat_messages.created_at > chat_channel_members.last_read_at')
      .group(:chat_channel_id)
      .count
  end

  # O outro participante de uma conversa privada.
  def peer_for(user)
    return if channel?

    members.find { |member| member.id != user.id }
  end

  def display_name(user = nil)
    channel? ? name : peer_for(user)&.name
  end

  # Quem pode escrever aqui. `administrator` vem de fora porque papel e da conta,
  # nao da sala - o model nao tem como descobrir sozinho.
  def postable_by?(user, administrator: false)
    return true if posting_everyone?
    return true if administrator

    chat_channel_members.exists?(user_id: user.id, can_post: true)
  end

  # A ultima mensagem, para a previa da barra lateral.
  #
  # `attr_writer` porque a LISTAGEM preenche isto de fora: ela busca a ultima
  # mensagem de todas as salas numa consulta so (`last_messages_for`). Sem isso
  # seria uma consulta por sala, em toda visita ao Chat.
  attr_writer :last_message

  def last_message
    @last_message ||= chat_messages.order(id: :desc).first
  end

  # O maior id E a mais recente: id cresce sempre, e comparar ids evita empate
  # entre duas mensagens gravadas no mesmo instante.
  def self.last_messages_for(channel_ids)
    return {} if channel_ids.blank?

    ultimos = ChatMessage.where(chat_channel_id: channel_ids).group(:chat_channel_id).select('MAX(id) AS id')
    ChatMessage.where(id: ultimos).includes(:user).index_by(&:chat_channel_id)
  end

  private

  def direct_has_no_name
    errors.add(:name, :invalid) if direct? && name.present?
  end
end
