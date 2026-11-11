json.id resource.id
json.ticket_id resource.ticket_id
json.category resource.category
json.note resource.note
# running | paused
json.status resource.status
# Quanto ja correu, contado no servidor NESTE instante. A tela soma o que passou desde
# que recebeu esta resposta (sem depender do relogio do aparelho estar certo).
json.elapsed_seconds resource.elapsed_seconds
json.created_at resource.created_at.to_i
