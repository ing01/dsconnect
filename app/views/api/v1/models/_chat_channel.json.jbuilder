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
# Canal fixo vai para o topo da barra lateral.
json.pinned resource.pinned
json.postingPolicy resource.posting_policy
# Quem pode escrever AQUI, ja resolvido para quem pediu: a tela precisa disso para
# desabilitar o campo, e recalcular a regra no navegador seria manter duas
# versoes dela.
json.canPost resource.postable_by?(Current.user, administrator: Current.account_user&.administrator?)
# Quem foi autorizado a escrever num canal de aviso. Administrador escreve sempre
# e por isso nao aparece aqui.
json.moderatorIds resource.chat_channel_members.select(&:can_post).map(&:user_id)
# A previa da barra lateral. Sem ela a lista dizia "Sem mensagens ainda" em toda
# sala que a pessoa ainda nao tinha aberto - as mensagens so chegam ao abrir, e a
# lista lia o que nao estava carregado.
json.lastMessage do
  ultima = resource.last_message
  if ultima.blank?
    json.nil!
  else
    json.id ultima.id
    json.userId ultima.user_id
    json.body ultima.content
    json.createdAt ultima.created_at.to_i
    # Mensagem so com anexo nao tem texto; a lista precisa mostrar alguma coisa.
    json.hasAttachments ultima.attachments.attached?
  end
end
