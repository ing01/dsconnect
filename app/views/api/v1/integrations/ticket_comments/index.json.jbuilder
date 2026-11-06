json.array! @ticket_comments do |comment|
  json.id comment.id
  json.content comment.content
  json.created_at comment.created_at.iso8601
  json.author_name comment.user&.name
end
