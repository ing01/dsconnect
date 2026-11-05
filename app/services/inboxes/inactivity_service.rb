# Aviso e encerramento por inatividade do cliente, configurados por caixa de
# entrada (`inactivity_config`, Portal do Cliente e WhatsApp). So' atua quando a
# ULTIMA mensagem da conversa foi da equipe - estamos esperando o cliente. As
# mensagens deste servico levam `inactivity_notice` e nao contam como mensagem
# da equipe, senao reiniciariam o relogio.
#
# Fluxo: passou `nudge_after` minutos da ultima mensagem da equipe -> envia o
# aviso (`inactivity_message`) e grava o momento; passou `close_after` minutos
# desde o aviso (ou desde a mensagem da equipe, se nao ha aviso configurado) e o
# cliente continua calado -> envia a mensagem de encerramento (`resolve_message`)
# e resolve. A avaliacao (CSAT) sai sozinha pelo evento de conversa resolvida,
# se estiver ativada na caixa. Se o cliente responder, tudo recomeca.
class Inboxes::InactivityService
  NOTICE_KEY = Queues::InactivityService::NOTICE_KEY
  NUDGED_AT_KEY = Queues::InactivityService::NUDGED_AT_KEY

  pattr_initialize [:inbox!]

  def perform
    nudge_after = inbox.inactivity_minutes('nudge_after')
    close_after = inbox.inactivity_minutes('close_after')
    threshold = [nudge_after, close_after].compact.min
    return if threshold.blank?

    inbox.conversations.open.where('last_activity_at <= ?', threshold.minutes.ago).find_each do |conversation|
      process(conversation, nudge_after, close_after)
    rescue StandardError => e
      # Uma conversa com problema nao pode travar as outras; e' tentada de novo na proxima rodada.
      ChatwootExceptionTracker.new(e, account: inbox.account).capture_exception
    end
  end

  private

  def process(conversation, nudge_after, close_after)
    last_message = last_chat_message(conversation)
    return unless last_message&.outgoing?

    nudged_at = nudged_at_for(conversation, last_message)
    if nudged_at
      close(conversation, nudged_at) if close_after && elapsed?(nudged_at, close_after)
    elsif nudge_after
      nudge(conversation) if elapsed?(last_message.created_at, nudge_after)
    elsif close_after && elapsed?(last_message.created_at, close_after)
      close(conversation, last_message.created_at)
    end
  end

  def last_chat_message(conversation)
    conversation.messages
                .where(message_type: [:incoming, :outgoing], private: false)
                .where("COALESCE(content_attributes ->> '#{NOTICE_KEY}', '') = ''")
                .order(:created_at, :id).last
  end

  # O aviso so vale se for posterior a ultima mensagem da equipe.
  def nudged_at_for(conversation, last_message)
    value = conversation.additional_attributes&.dig(NUDGED_AT_KEY)
    nudged_at = value && Time.zone.parse(value)
    nudged_at if nudged_at && nudged_at > last_message.created_at
  end

  def elapsed?(since, minutes)
    since <= minutes.minutes.ago
  end

  def nudge(conversation)
    send_notice(conversation, inbox.inactivity_config['inactivity_message'], 'nudge')
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(NUDGED_AT_KEY => Time.current.iso8601))
  end

  def close(conversation, since)
    ActiveRecord::Base.transaction do
      send_notice(conversation, inbox.inactivity_config['resolve_message'], 'close')
      conversation.inactivity_resolved_after = ((Time.current - since) / 60).round
      conversation.update!(status: :resolved)
    end
  end

  def send_notice(conversation, content, kind)
    return if content.blank? || !conversation.can_reply?

    conversation.messages.create!(
      account_id: conversation.account_id, inbox_id: inbox.id, message_type: :outgoing,
      content: content, content_attributes: { NOTICE_KEY => kind }
    )
  end
end
