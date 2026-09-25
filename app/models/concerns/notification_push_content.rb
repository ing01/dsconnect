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
      'ticket_triage_pending' => 'notifications.notification_title.ticket_triage_pending'
    }

    i18n_key = notification_title_map[notification_type]
    return '' unless i18n_key

    in_account_locale { I18n.t(i18n_key, **title_interpolations) }
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
      { sender_name: primary_actor.user&.name.to_s }
    when 'ticket_triage_pending'
      { display_id: primary_actor.display_id, company_name: primary_actor.company&.name.to_s }
    else
      # A familia das conversas, mais os SLAs. Chave sobrando e ignorada pela
      # interpolacao, entao um ramo so responde por todas.
      { display_id: primary_actor.display_id, contact_name: requester_name }
    end
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
    when 'internal_chat_message'
      internal_chat_preview
    else
      ''
    end
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
end
