# Uma linha por sessao encerrada: id (para abrir), quando comecou/terminou e
# um resumo da ultima mensagem - o bastante para reconhecer qual e qual sem
# abrir uma por uma.
json.array! @conversations do |conversation|
  ultima = conversation.messages.chat.order(created_at: :desc).first

  json.id conversation.display_id
  json.created_at conversation.created_at.to_i
  json.resolved_at (conversation.status_changed_at || conversation.updated_at).to_i
  json.preview ultima&.content.to_s.truncate(120)
end
