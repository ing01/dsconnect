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
      'internal_chat_message' => 'notifications.notification_title.internal_chat_message'
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
    when 'conversation_assignment', 'assigned_conversation_new_message',
         'participating_conversation_new_message', 'conversation_mention'
      { display_id: conversation.display_id, contact_name: requester_name }
    when 'project_contract_end_overdue', 'project_support_end_overdue'
      { project_name: primary_actor.name }
    when 'internal_chat_message'
      { sender_name: primary_actor.user&.name.to_s }
    else
      { display_id: primary_actor.display_id }
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

  def internal_chat_preview
    content = primary_actor.content.to_s.strip
    return I18n.t('notifications.notification_body.internal_chat_attachment') if content.blank?

    content.truncate(INTERNAL_CHAT_PREVIEW_LIMIT)
  end

  # Para onde o clique leva, SEM host. O host certo e aquele que a pessoa ja
  # esta usando, e quem sabe disso e o navegador: o service worker resolve este
  # caminho contra a propria origem. Gravar o host aqui significaria depender do
  # FRONTEND_URL, que envelhece a cada troca de endereco - e um tunel temporario
  # troca de endereco a cada reinicio, levando a notificacao para um lugar morto.
  def push_target_path
    case primary_actor_type
    when 'ChatMessage'
      # A tela do Chat Interno escolhe a sala por `?room=` (InternalChatPage).
      # Nao ha helper de rota para ela: o /app e servido pelo mesmo dashboard
      # e as rotas internas sao do lado do navegador.
      "/app/accounts/#{account_id}/internal-chat?room=#{primary_actor.chat_channel_id}"
    when 'Project'
      "/app/accounts/#{account_id}/projects?project=#{primary_actor_id}"
    else
      app_account_conversation_path(account_id: account_id, id: conversation.display_id)
    end
  end

  # Versao absoluta, para quem precisa de host: e-mail, por exemplo, que nao tem
  # navegador para resolver caminho relativo.
  def push_target_url
    "#{frontend_base_url}#{push_target_path}"
  end

  def frontend_base_url
    ENV.fetch('FRONTEND_URL', '')
  end
end
