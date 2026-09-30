# Uma mensagem do chat, como o cliente a ve - sem nada do que so a equipe
# enxerga (notas privadas ja ficam fora pelo escopo `.chat`).
json.id resource.id
json.content resource.content
json.from_you resource.sender_type == 'Contact'
json.author_name resource.sender_type == 'User' ? resource.sender&.name : nil
json.created_at resource.created_at.to_i
