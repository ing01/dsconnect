# Uma mensagem do Chat Interno.
class ChatMessage < ApplicationRecord
  include Events::Types
  # Para o url_for dos anexos, como no model Attachment.
  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :chat_channel
  # Nulo quando o agente e removido: a conversa nao perde o historico.
  belongs_to :user, optional: true
  belongs_to :reply_to, class_name: 'ChatMessage', optional: true

  has_many :chat_message_reactions, dependent: :destroy

  # A imagem faz parte da mensagem: chega junto, sai junto, e o autor dela e o
  # autor da mensagem. Por isso vai direto no Active Storage, e nao num model de
  # juncao como o do Ticket - la o anexo tem vida propria (quem enviou, exclusao
  # avulsa), aqui nao tem.
  has_many_attached :attachments

  MAXIMUM_ATTACHMENT_SIZE = 25.megabytes
  MAXIMUM_ATTACHMENTS = 10

  # Mensagem so com imagem e legitima, entao o texto so e exigido quando nao ha
  # nada anexado.
  validates :content, presence: true, unless: :attachments_attached?
  validate :attachments_within_limits

  before_validation :ensure_account_id
  # A sala guarda a data da ultima mensagem para poder ser ordenada sem varrer
  # a tabela de mensagens.
  after_create_commit :touch_channel, :dispatch_created_event

  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  # O mesmo formato que a API devolve, para que a mensagem que chega pelo tempo
  # real e a que vem por HTTP sejam indistinguiveis na tela.
  def push_event_data
    {
      id: id,
      userId: user_id,
      body: content,
      createdAt: created_at.to_i,
      replyTo: reply_to_id,
      reactions: reactions_payload.map { |item| { emoji: item[:emoji], userIds: item[:user_ids] } },
      # Sem isto a imagem apareceria para quem enviou e nao para quem recebe
      # pelo tempo real, que e o mesmo defeito que ja corrigimos no texto.
      attachments: attachments_payload
    }
  end

  # Avisa quem participa da sala. Chamado tambem quando uma reacao muda, porque
  # a tela substitui a mensagem inteira.
  def dispatch_updated_event
    dispatch_event(INTERNAL_CHAT_MESSAGE_UPDATED)
  end

  # O que a tela precisa para desenhar cada anexo. `thumb` so existe para
  # imagem, e volta vazio quando o arquivo nao pode ser redimensionado.
  def attachments_payload
    attachments.map do |attachment|
      {
        id: attachment.id,
        name: attachment.filename.to_s,
        byteSize: attachment.byte_size,
        contentType: attachment.content_type,
        kind: image?(attachment) ? 'image' : 'file',
        url: url_for(attachment),
        thumb: thumb_for(attachment)
      }
    end
  end

  # As reacoes agrupadas por emoji, no formato que a tela desenha.
  def reactions_payload
    chat_message_reactions.group_by(&:emoji).map do |emoji, reactions|
      { emoji: emoji, user_ids: reactions.map(&:user_id) }
    end
  end

  private

  def attachments_attached?
    attachments.attached?
  end

  def image?(attachment)
    attachment.content_type.to_s.start_with?('image/')
  end

  def thumb_for(attachment)
    return '' unless image?(attachment)

    url_for(attachment.representation(resize_to_limit: [480, 480]))
  rescue ActiveStorage::UnrepresentableError
    # Formato que o processador nao abre (um SVG, por exemplo). A imagem em
    # tamanho cheio continua servindo; so nao ha miniatura.
    ''
  end

  def attachments_within_limits
    return unless attachments.attached?

    errors.add(:attachments, I18n.t('errors.chat_message.too_many', count: MAXIMUM_ATTACHMENTS)) if attachments.size > MAXIMUM_ATTACHMENTS

    return if attachments.all? { |item| item.byte_size <= MAXIMUM_ATTACHMENT_SIZE }

    errors.add(:attachments, I18n.t('errors.chat_message.too_large', size: MAXIMUM_ATTACHMENT_SIZE / 1.megabyte))
  end

  def ensure_account_id
    self.account_id ||= chat_channel&.account_id
  end

  def touch_channel
    chat_channel.update_column(:last_message_at, created_at) # rubocop:disable Rails/SkipsModelValidations
  end

  def dispatch_created_event
    dispatch_event(INTERNAL_CHAT_MESSAGE_CREATED)
  end

  def dispatch_event(name)
    Rails.configuration.dispatcher.dispatch(name, Time.zone.now, chat_message: self)
  end
end
