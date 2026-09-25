if @conversation.present?
  json.conversation do
    json.id @conversation.id
    json.display_id @conversation.display_id
  end
else
  json.conversation nil
end
