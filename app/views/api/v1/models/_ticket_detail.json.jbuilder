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
  json.last_activity_at conversation.last_activity_at&.to_i
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
