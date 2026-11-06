# Como os servicos de inatividade (Fila e caixa) reconhecem as PROPRIAS mensagens
# (aviso, encerramento, pausa...) e o aviso que ja foi enviado.
#
# As mensagens deste fluxo levam `content_attributes.inactivity_notice` e nao
# contam como mensagem da equipe, senao o aviso reiniciaria o relogio.
#
# IMPORTANTE: a leitura e' feita em Ruby (pelo `store` do Message), NUNCA por
# `content_attributes ->> 'chave'` no SQL. `Message` grava `content_attributes`
# com `store ..., coder: JSON` numa coluna `json`, o que pode deixar o valor como
# TEXTO JSON (codificado duas vezes) - e nesse formato o operador `->>` devolve
# sempre NULL. Foi isso que fazia o aviso nunca ser reconhecido: ele virava a
# "ultima mensagem da equipe", o relogio recomecava e o aviso saia a cada ciclo,
# sem nunca chegar a pausa/encerramento. Por isso a regra vale em qualquer formato.
module Inactivity::NoticeTracking
  NOTICE_KEY = 'inactivity_notice'.freeze
  NUDGED_AT_KEY = 'inactivity_nudged_at'.freeze
  # Basta olhar as mensagens mais recentes: os avisos sao sempre os ultimos.
  RECENT_MESSAGES_LIMIT = 30

  private

  # Mensagens de chat (cliente e equipe, sem nota privada), da mais nova pra mais antiga.
  def recent_chat_messages(conversation)
    conversation.messages
                .where(message_type: [:incoming, :outgoing], private: false)
                .reorder(created_at: :desc, id: :desc)
                .limit(RECENT_MESSAGES_LIMIT)
                .to_a
  end

  # Ultima mensagem que NAO e' deste fluxo (a que de fato diz de quem e' a vez).
  def last_chat_message(conversation)
    recent_chat_messages(conversation).find { |message| inactivity_notice(message).blank? }
  end

  # Tipo do aviso da mensagem ('nudge', 'close', 'pause'...) ou nil se nao e' deste fluxo.
  def inactivity_notice(message)
    attributes = message.content_attributes
    attributes[NOTICE_KEY].presence if attributes.respond_to?(:key?)
  end

  # O aviso so vale se for posterior a ultima mensagem de chat.
  def nudged_at_for(conversation, last_message)
    value = conversation.additional_attributes&.dig(NUDGED_AT_KEY)
    nudged_at = value && Time.zone.parse(value)
    nudged_at = nil unless nudged_at && nudged_at > last_message.created_at
    nudged_at || nudge_notice_time(conversation, last_message)
  end

  # Fonte da verdade do aviso ja enviado: o marcador em `additional_attributes`
  # e, se ele nao foi gravado, a PROPRIA mensagem de aviso.
  def nudge_notice_time(conversation, last_message)
    recent_chat_messages(conversation)
      .select { |message| message.created_at > last_message.created_at && inactivity_notice(message) == 'nudge' }
      .map(&:created_at).min
  end

  # Prazo (contado a partir do aviso) para pausar ou encerrar a conversa.
  # - Com pausa disponivel: o prazo da pausa.
  # - Sem pausa disponivel (desligada ou ja usada o maximo de vezes): o de
  #   encerramento. Se so houver pausa configurada (sem "encerrar apos"), o mesmo
  #   prazo da pausa encerra de vez - senao a conversa que ja foi pausada e voltou
  #   nunca mais encerraria, so receberia avisos.
  def final_delay_for(pause, pause_config, close_after)
    return pause.config.pause_after if pause

    close_after.presence || (pause_config.pause_after if pause_config.enabled?)
  end

  # Marcador com microssegundos: com precisao de segundos ele podia ficar ANTES da
  # propria mensagem de aviso e ser descartado.
  def nudge_marker
    { NUDGED_AT_KEY => Time.current.iso8601(6) }
  end
end
