json.id resource.id
json.userId resource.user_id
json.body resource.content
json.createdAt resource.created_at.to_i
json.pinnedAt resource.pinned_at&.to_i
json.replyTo resource.reply_to_id
json.reactions resource.reactions_payload do |reaction|
  json.emoji reaction[:emoji]
  json.userIds reaction[:user_ids]
end
json.attachments resource.attachments_payload do |attachment|
  json.id attachment[:id]
  json.name attachment[:name]
  json.byteSize attachment[:byteSize]
  json.contentType attachment[:contentType]
  json.kind attachment[:kind]
  json.url attachment[:url]
  json.thumb attachment[:thumb]
end
