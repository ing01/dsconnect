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

  validates :name, presence: true, if: :channel?
  validates :name, uniqueness: { scope: :account_id }, if: -> { channel? && name.present? }
  validate :direct_has_no_name

  scope :ordered, -> { order(Arel.sql('COALESCE(last_message_at, created_at) DESC')) }
  # As salas de uma pessoa: canais em que ela esta e as conversas dela.
  scope :for_user, lambda { |user|
    where(id: ChatChannelMember.where(user_id: user.id).select(:chat_channel_id))
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
  def unread_count_for(user)
    membership = chat_channel_members.find_by(user_id: user.id)
    return 0 if membership.blank?

    scope = chat_messages.where.not(user_id: user.id)
    scope = scope.where('chat_messages.created_at > ?', membership.last_read_at) if membership.last_read_at
    scope.count
  end

  # O outro participante de uma conversa privada.
  def peer_for(user)
    return if channel?

    members.find { |member| member.id != user.id }
  end

  def display_name(user = nil)
    channel? ? name : peer_for(user)&.name
  end

  private

  def direct_has_no_name
    errors.add(:name, :invalid) if direct? && name.present?
  end
end
