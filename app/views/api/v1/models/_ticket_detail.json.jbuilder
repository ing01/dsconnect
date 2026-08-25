# The Ticket payload for single-record endpoints. The lean `_ticket` partial is
# rendered once per ticket by the Kanban board (`_ticket_column` inlines every
# ticket of every column) and by the paginated list, so the detail-only fields
# live here instead of being paid for on those hot paths.
#
# `sort_by` is deliberate throughout: `.order` on a preloaded association issues
# a fresh query and throws away the controller's `includes`.
json.partial! 'api/v1/models/ticket', formats: [:json], resource: resource

contact = resource.requester_contact
if contact
  json.contact do
    json.id contact.id
    json.name contact.name
    json.email contact.email
    json.phone_number contact.phone_number
    json.thumbnail contact.avatar_url
    json.company_id contact.company_id
  end
else
  json.contact nil
end

# `id` is the internal PK - what the unlink endpoint and the `conversation_id`
# filter expect. `display_id` is what the dashboard router resolves against
# (conversations#show does `find_by!(display_id:)`), so navigation must use it.
json.conversations resource.conversations.sort_by(&:id) do |conversation|
  json.id conversation.id
  json.display_id conversation.display_id
  json.status conversation.status
  json.channel conversation.inbox&.channel_type
  json.inbox_id conversation.inbox_id
  json.inbox_name conversation.inbox&.name
  json.contact_name conversation.contact&.name
  json.company_name conversation.contact&.company&.name
  json.last_activity_at conversation.last_activity_at&.to_i
  # A short preview so "Conversas relacionadas" can be told apart at a glance
  # when several conversations share the same contact and channel. Fetched with
  # an explicit LIMIT 1 rather than preloaded: preloading every message of every
  # linked conversation to read one of them would cost far more, and a ticket
  # links a handful of conversations at most.
  last_message = conversation.messages.chat.order(created_at: :desc).first
  json.last_message last_message&.content&.to_s&.truncate(120)
end

created_by = resource.created_by_user
if created_by
  json.created_by do
    json.id created_by.id
    json.name created_by.name
    json.thumbnail created_by.avatar_url
  end
else
  json.created_by nil
end

json.attachments resource.ticket_attachments.sort_by(&:id).reverse do |attachment|
  json.partial! 'api/v1/models/ticket_attachment', formats: [:json], resource: attachment
end

# Parent/child and grouping. Only the identifying fields are inlined - the
# related tickets are reachable by their own detail endpoint, and nesting whole
# tickets here would recurse.
ticket_ref = lambda do |ticket|
  json.id ticket.id
  json.display_id ticket.display_id
  json.title ticket.title
  json.status ticket.status
end

if resource.parent
  json.parent { ticket_ref.call(resource.parent) }
else
  json.parent nil
end

json.children resource.children.sort_by(&:display_id) do |child|
  ticket_ref.call(child)
end

if resource.merged_into
  json.merged_into { ticket_ref.call(resource.merged_into) }
else
  json.merged_into nil
end

json.merged_tickets resource.merged_tickets.sort_by(&:display_id) do |merged|
  ticket_ref.call(merged)
end

json.followers resource.ticket_followers.sort_by(&:id) do |follower|
  json.id follower.id
  json.user_id follower.user_id
  json.name follower.user.name
  json.thumbnail follower.user.avatar_url
end

# Newest first: the most recent extension is the one that explains the current
# deadline.
json.sla_extensions resource.ticket_sla_extensions.sort_by(&:id).reverse do |extension|
  json.id extension.id
  json.hours extension.hours.to_f
  json.reason extension.reason
  json.user_name extension.user&.name
  json.previous_due_at extension.previous_due_at&.to_i
  json.new_due_at extension.new_due_at&.to_i
  json.created_at extension.created_at.to_i
end
