# Como uma notificacao se apresenta num push: titulo, corpo e para onde o
# clique leva.
#
# Separado do model porque e responsabilidade propria - e porque a Notification
# ja atende Conversation, Project e Chat Interno, e cada um acrescenta um caso
# a esses metodos.
module NotificationPushContent
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  def push_message_title
    notification_title_map = {
      'conversation_creation' => 'notifications.notification_title.conversation_creation',
      'conversation_assignment' => 'notifications.notification_title.conversation_assignment',
      'assigned_conversation_new_message' => 'notifications.notification_title.assigned_conversation_new_message',
      'participating_conversation_new_message' => 'notifications.notification_title.assigned_conversation_new_message',
      'conversation_mention' => 'notifications.notification_title.conversation_mention',
      'sla_missed_first_response' => 'notifications.notification_title.sla_missed_first_response',
      'sla_missed_next_response' => 'notifications.notification_title.sla_missed_next_response',
      'sla_missed_resolution' => 'notifications.notification_title.sla_missed_resolution',
      'project_contract_end_overdue' => 'notifications.notification_title.project_contract_end_overdue',
      'project_support_end_overdue' => 'notifications.notification_title.project_support_end_overdue',
      'internal_chat_message' => 'notifications.notification_title.internal_chat_message',
      'ticket_triage_pending' => 'notifications.notification_title.ticket_triage_pending',
      'suggestion_created' => 'notifications.notification_title.suggestion_created',
      'ticket_customer_communication_received' => 'notifications.notification_title.ticket_customer_communication_received',
      'article_published' => 'notifications.notification_title.article_published',
      'portal_created' => 'notifications.notification_title.portal_created'
    }

    i18n_key = internal_chat_title_key || notification_title_map[notification_type]
    return '' unless i18n_key

    in_account_locale { I18n.t(i18n_key, **title_interpolations) }
  end

  # Mensagem de CANAL se anuncia pelo canal: "Comunicados - Ana" diz de onde vem
  # e quem escreveu, enquanto "Chat interno" era igual para tudo e nao distinguia
  # um canal de outro na bandeja. Conversa entre duas pessoas nao tem canal para
  # nomear e segue com o titulo generico - ali o nome de quem escreveu ja abre o
  # corpo do aviso.
  def internal_chat_title_key
    return unless notification_type == 'internal_chat_message'
    return unless primary_actor&.chat_channel&.channel?

    'notifications.notification_title.internal_chat_channel_message'
  end

  # O idioma vem da conta, sempre. `I18n.locale` e por thread e o Sidekiq
  # reaproveita threads entre jobs: sem fixar aqui, o mesmo aviso saia ora em
  # portugues ora em ingles, conforme o que o job anterior tivesse deixado.
  def in_account_locale(&)
    locale = account&.locale.presence
    locale = nil unless locale && I18n.available_locales.include?(locale.to_sym)

    I18n.with_locale(locale || I18n.default_locale, &)
  end

  # O que cada titulo precisa para ser montado. Separado do mapa de chaves
  # porque cada familia de notificacao fala de um ator diferente.
  def title_interpolations
    case notification_type
    when 'conversation_creation'
      { display_id: conversation.display_id, inbox_name: primary_actor.inbox.name, contact_name: requester_name }
    when 'project_contract_end_overdue', 'project_support_end_overdue'
      { project_name: primary_actor.name }
    when 'internal_chat_message'
      internal_chat_interpolations
    when 'ticket_triage_pending', 'ticket_customer_communication_received'
      { display_id: primary_actor.display_id, company_name: primary_actor.company&.name.to_s }
    when 'suggestion_created'
      { user_name: primary_actor.user&.name.to_s }
    when 'article_published'
      { article_title: primary_actor.title }
    when 'portal_created'
      { portal_name: primary_actor.name }
    else
      # A familia das conversas, mais os SLAs. Chave sobrando e ignorada pela
      # interpolacao, entao um ramo so responde por todas.
      { display_id: primary_actor.display_id, contact_name: requester_name }
    end
  end

  # Duas chaves: quem escreveu e onde. O canal so existe quando a sala e um canal;
  # numa conversa entre duas pessoas ele fica vazio, e o titulo generico nem o usa.
  def internal_chat_interpolations
    { sender_name: primary_actor.user&.name.to_s,
      channel_name: primary_actor.chat_channel&.name.to_s }
  end

  # Quem abriu a conversa. E o nome que o agente reconhece na notificacao:
  # "conversa #32" nao diz nada, "Maria - conversa #32" diz.
  def requester_name
    conversation&.contact&.name.presence || I18n.t('notifications.unknown_contact')
  end

  def push_message_body
    in_account_locale { message_body_for_type }
  end

  def message_body_for_type
    case notification_type
    when 'conversation_creation', 'sla_missed_first_response'
      message_body(conversation.messages.first)
    when 'assigned_conversation_new_message', 'participating_conversation_new_message', 'conversation_mention'
      message_body(secondary_actor)
    when 'conversation_assignment', 'sla_missed_next_response', 'sla_missed_resolution'
      message_body((conversation.messages.incoming.last || conversation.messages.outgoing.last))
    else
      message_body_for_non_conversation_type
    end
  end

  def message_body_for_non_conversation_type
    return internal_chat_preview if notification_type == 'internal_chat_message'
    return primary_actor.title if %w[suggestion_created article_published ticket_triage_pending].include?(notification_type)
    return primary_actor.name if notification_type == 'portal_created'
    return ticket_customer_communication_preview if notification_type == 'ticket_customer_communication_received'

    ''
  end

  # So uma previa: a notificacao aparece na tela de bloqueio, e mandar a
  # mensagem inteira exporia conteudo a quem estiver olhando o aparelho.
  INTERNAL_CHAT_PREVIEW_LIMIT = 80

  # Duas linhas: quem escreveu e o que escreveu. O titulo fica com "Chat
  # interno", que e o que identifica a origem do aviso quando ele chega junto de
  # notificacoes de conversa - so o nome da pessoa nao dizia de onde vinha.
  def internal_chat_preview
    sender_name = primary_actor.user&.name.to_s
    content = primary_actor.content.to_s.strip

    if content.blank?
      I18n.t('notifications.notification_body.internal_chat_attachment', sender_name: sender_name)
    else
      I18n.t('notifications.notification_body.internal_chat_message',
             sender_name: sender_name,
             content: content.truncate(INTERNAL_CHAT_PREVIEW_LIMIT))
    end
  end

  # `secondary_actor` e' a TicketCustomerCommunication - formato diferente do
  # que `message_body` espera, por isso a previa propria.
  def ticket_customer_communication_preview
    content = secondary_actor.body.to_s.strip
    "#{secondary_actor.author_name}: #{content.truncate_words(10)}"
  end
end
