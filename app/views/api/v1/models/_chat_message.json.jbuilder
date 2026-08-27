json.id resource.id
json.userId resource.user_id
json.body resource.content
json.createdAt resource.created_at.to_i
json.replyTo resource.reply_to_id
json.reactions resource.reactions_payload do |reaction|
  json.emoji reaction[:emoji]
  json.userIds reaction[:user_ids]
end
