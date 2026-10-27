# Aviso e encerramento por inatividade do chat do Portal/app, de acordo com as
# regras da Fila (`inactivity_*` em ServiceQueue).
#
# So' atua quando a ULTIMA mensagem da conversa foi da equipe - ou seja, quando
# estamos esperando o cliente. As mensagens deste proprio servico (marcadas em
# `content_attributes.inactivity_notice`) nao contam como mensagem da equipe,
# senao o aviso reiniciaria o relogio.
#
# Fluxo: passou `inactivity_nudge_after` desde a ultima mensagem da equipe ->
# manda o aviso e grava `inactivity_nudged_at`; passou `inactivity_close_after`
# desde o aviso (ou desde a mensagem da equipe, se a Fila nao tem aviso) e o
# cliente continua calado -> manda a mensagem de encerramento e resolve. Se o
# cliente responder, a ultima mensagem deixa de ser da equipe e tudo recomeca.
# Ao encerrar, os Tickets vinculados a conversa tambem sao fechados.
class Queues::InactivityService
  NOTICE_KEY = 'inactivity_notice'.freeze
  NUDGED_AT_KEY = 'inactivity_nudged_at'.freeze

  pattr_initialize [:queue!]

  def perform
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(queue.account)
    return if inbox.blank?

    queue.conversations.where(inbox_id: inbox.id, status: :open).find_each do |conversation|
      process(conversation)
    rescue StandardError => e
      # Uma conversa com problema nao pode travar as outras. A transacao de
      # `close` desfaz tudo, entao ela e' tentada de novo na proxima rodada.
      ChatwootExceptionTracker.new(e, account: queue.account).capture_exception
    end
  end

  private

  def process(conversation)
    last_message = last_chat_message(conversation)
    return unless last_message&.outgoing?

    nudged_at = nudged_at_for(conversation, last_message)
    if nudged_at
      close(conversation, nudged_at) if close_due?(nudged_at)
    elsif queue.inactivity_nudge_after.present?
      nudge(conversation) if elapsed?(last_message.created_at, queue.inactivity_nudge_after)
    elsif queue.inactivity_close_after.present? && elapsed?(last_message.created_at, queue.inactivity_close_after)
      close(conversation, last_message.created_at)
    end
  end

  def last_chat_message(conversation)
    conversation.messages
                .where(message_type: [:incoming, :outgoing], private: false)
                .where("COALESCE(content_attributes ->> '#{NOTICE_KEY}', '') = ''")
                .order(:created_at, :id).last
  end

  # O aviso so vale se for posterior a ultima mensagem da equipe; um aviso de
  # uma rodada anterior (o cliente respondeu e a equipe falou de novo) e' ignorado.
  def nudged_at_for(conversation, last_message)
    value = conversation.additional_attributes&.dig(NUDGED_AT_KEY)
    nudged_at = value && Time.zone.parse(value)
    nudged_at if nudged_at && nudged_at > last_message.created_at
  end

  def close_due?(nudged_at)
    queue.inactivity_close_after.present? && elapsed?(nudged_at, queue.inactivity_close_after)
  end

  def elapsed?(since, minutes)
    since <= minutes.minutes.ago
  end

  def nudge(conversation)
    send_notice(conversation, queue.inactivity_nudge_message, 'nudge')
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(NUDGED_AT_KEY => Time.current.iso8601))
  end

  # Aviso, resolucao da conversa e fechamento dos tickets vinculados andam
  # juntos: se qualquer passo falhar, nada fica pela metade.
  def close(conversation, since)
    ActiveRecord::Base.transaction do
      send_notice(conversation, queue.inactivity_close_message, 'close')
      conversation.inactivity_resolved_after = ((Time.current - since) / 60).round
      conversation.update!(status: :resolved)
      close_tickets(conversation)
    end
  end

  # Fechamento administrativo (como o agrupamento de tickets): a inatividade nao
  # e' um atendimento concluido pela equipe, entao nao exige categoria,
  # classificacao nem comunicacao de fechamento - senao o ticket ficaria aberto
  # para sempre numa conversa ja encerrada.
  def close_tickets(conversation)
    conversation.tickets.where(status: [:open, :resolved]).find_each do |ticket|
      ticket.close!(nil, skip_requirements: true)
      ticket.as_administrative_change { ticket.update!(close_reason: 'inactivity') }
    end
  end

  # `outgoing` (e nao `template`) porque e' o tipo que dispara o push para o
  # cliente (ClientPortalChatListener) - o aviso precisa chegar no celular.
  def send_notice(conversation, content, kind)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: content,
      content_attributes: { NOTICE_KEY => kind }
    )
  end
end
