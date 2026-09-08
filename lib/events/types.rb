# frozen_string_literal: true

module Events::Types
  ### Installation Events ###
  # account events
  ACCOUNT_CREATED = 'account.created'
  ACCOUNT_CACHE_INVALIDATED = 'account.cache_invalidated'

  #### Account Events ###
  # campaign events
  CAMPAIGN_TRIGGERED = 'campaign.triggered'

  # channel events
  WEBWIDGET_TRIGGERED = 'webwidget.triggered'

  # conversation events
  CONVERSATION_CREATED = 'conversation.created'
  CONVERSATION_UPDATED = 'conversation.updated'
  CONVERSATION_DELETED = 'conversation.deleted'
  CONVERSATION_READ = 'conversation.read'
  CONVERSATION_BOT_HANDOFF = 'conversation.bot_handoff'
  # FIXME: deprecate the opened and resolved events in future in favor of status changed event.
  CONVERSATION_OPENED = 'conversation.opened'
  CONVERSATION_RESOLVED = 'conversation.resolved'
  CAPTAIN_CONVERSATION_HANDED_OFF = 'captain.conversation.handed_off'
  CAPTAIN_CONVERSATION_RESOLVED = 'captain.conversation.resolved'
  CAPTAIN_RESPONSE_COMPLETED = 'captain.response.completed'
  CAPTAIN_RESPONSE_FAILED = 'captain.response.failed'

  CONVERSATION_STATUS_CHANGED = 'conversation.status_changed'
  CONVERSATION_CONTACT_CHANGED = 'conversation.contact_changed'
  CONVERSATION_UNREAD_COUNT_CHANGED = 'conversation.unread_count_changed'
  ASSIGNEE_CHANGED = 'assignee.changed'
  TEAM_CHANGED = 'team.changed'
  CONVERSATION_TYPING_ON = 'conversation.typing_on'
  CONVERSATION_TYPING_OFF = 'conversation.typing_off'
  CONVERSATION_MENTIONED = 'conversation.mentioned'

  # message events
  MESSAGE_CREATED = 'message.created'
  FIRST_REPLY_CREATED = 'first.reply.created'
  REPLY_CREATED = 'reply.created'
  MESSAGE_UPDATED = 'message.updated'

  # contact events
  CONTACT_CREATED = 'contact.created'
  CONTACT_UPDATED = 'contact.updated'
  CONTACT_MERGED = 'contact.merged'
  CONTACT_DELETED = 'contact.deleted'

  # contact events
  INBOX_CREATED = 'inbox.created'
  INBOX_UPDATED = 'inbox.updated'

  # notification events
  NOTIFICATION_CREATED = 'notification.created'
  NOTIFICATION_DELETED = 'notification.deleted'
  NOTIFICATION_UPDATED = 'notification.updated'

  # agent events
  AGENT_ADDED = 'agent.added'
  AGENT_REMOVED = 'agent.removed'

  # ticket events
  TICKET_CREATED = 'ticket.created'
  TICKET_UPDATED = 'ticket.updated'
  TICKET_MOVED = 'ticket.moved'
  TICKET_DELETED = 'ticket.deleted'
  TICKET_RESOLVED = 'ticket.resolved'
  TICKET_REOPENED = 'ticket.reopened'
  TICKET_CLOSED = 'ticket.closed'
  TICKET_CANCELLED = 'ticket.cancelled'
  # Um relogio de SLA do ticket estourou. Alimenta o realtime e e o gancho por
  # onde as notificacoes de vencimento entram, sem engine nova.
  TICKET_SLA_MISSED = 'ticket.sla_missed'

  # Chat Interno. Transmitidos apenas aos membros da sala - uma conversa entre
  # funcionarios nunca vai para quem nao participa dela.
  INTERNAL_CHAT_MESSAGE_CREATED = 'internal_chat.message.created'
  INTERNAL_CHAT_MESSAGE_UPDATED = 'internal_chat.message.updated'

  # copilot events
  COPILOT_MESSAGE_CREATED = 'copilot.message.created'
end
