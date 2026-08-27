json.id resource.id
json.kind resource.kind
json.name resource.name
json.description resource.description
json.visibility resource.visibility
json.memberIds resource.members.map(&:id)
# Quem esta do outro lado, nas conversas privadas. O canal nao tem par.
json.userId resource.peer_for(Current.user)&.id
# Contado no servidor e por pessoa: o mesmo numero em qualquer aparelho.
json.unread resource.unread_count_for(Current.user)
json.lastMessageAt resource.last_message_at&.to_i
