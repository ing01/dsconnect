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
  include Inactivity::NoticeTracking

  NOTICE_KEY = Inactivity::NoticeTracking::NOTICE_KEY
  NUDGED_AT_KEY = Inactivity::NoticeTracking::NUDGED_AT_KEY

  pattr_initialize [:queue!]

  def perform
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(queue.account)
    return if inbox.blank?

    @inbox = inbox
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

    pause = pause_service(conversation)
    final_delay = final_delay_for(pause, queue.pause_config, queue.inactivity_close_after)
    nudged_at = nudged_at_for(conversation, last_message)
    if nudged_at
      finish(conversation, pause, nudged_at) if final_delay.present? && elapsed?(nudged_at, final_delay)
    elsif queue.inactivity_nudge_after.present?
      nudge(conversation) if elapsed?(last_message.created_at, queue.inactivity_nudge_after)
    elsif final_delay.present? && elapsed?(last_message.created_at, final_delay)
      finish(conversation, pause, last_message.created_at)
    end
  end

  # Pausa (se o fluxo esta ligado na Fila e ainda ha pausa disponivel pra esta
  # conversa) ou encerra direto, como sempre foi.
  def pause_service(conversation)
    service = Inactivity::PauseService.new(conversation: conversation, config: queue.pause_config, origin: 'queue', close_tickets: true)
    service if service.allowed?
  end

  def finish(conversation, pause, since)
    pause ? pause.pause! : close(conversation, since)
  end

  # Com a pausa ligada na Fila, os prazos so correm no horario de atendimento da
  # caixa do Portal (se a configuracao pedir e a caixa tiver horario ligado).
  def elapsed?(since, minutes)
    config = queue.pause_config
    Inactivity::BusinessTime.new(@inbox, enabled: config.enabled? && config.respect_working_hours?).elapsed?(since, minutes)
  end

  # O aviso e o marcador saem na mesma transacao, com a conversa TRAVADA e
  # recarregada: se outra rodada (ou outro job) avisou enquanto esperavamos, o
  # estado novo ja mostra o aviso e nao mandamos de novo.
  def nudge(conversation)
    conversation.with_lock do
      last_message = last_chat_message(conversation)
      next unless conversation.open? && last_message&.outgoing? && nudged_at_for(conversation, last_message).nil?

      send_notice(conversation, queue.inactivity_nudge_message, 'nudge')
      conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(nudge_marker))
    end
  end

  # Aviso, resolucao da conversa e fechamento dos tickets vinculados andam
  # juntos: se qualquer passo falhar, nada fica pela metade. A conversa fica
  # travada e so' encerra se ainda estiver aberta e esperando o cliente.
  def close(conversation, since)
    conversation.with_lock do
      next unless conversation.open? && last_chat_message(conversation)&.outgoing?

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
