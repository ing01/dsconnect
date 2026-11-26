# Uma mensagem do chat, como o cliente a ve - sem nada do que so a equipe
# enxerga (notas privadas ja ficam fora pelo escopo `.chat`).
json.id resource.id
json.content ClientChatText.plain(resource.content)
json.content_type resource.content_type
json.from_you resource.sender_type == 'Contact'
json.author_name resource.sender_type == 'User' ? resource.sender&.name : nil
json.created_at resource.created_at.to_i
json.attachments resource.attachments do |anexo|
  json.merge! anexo.push_event_data || {}
end

# A mensagem respondida, para o balao mostrar a citacao. So' da mesma conversa e
# pelo escopo `.chat`: uma nota privada nunca chega ao cliente por aqui.
replied_id = resource.content_attributes['in_reply_to']
replied = replied_id.present? ? resource.conversation.messages.chat.find_by(id: replied_id) : nil
if replied
  json.reply_to do
    json.id replied.id
    json.content ClientChatText.plain(replied.content).to_s.truncate(200)
    json.from_you replied.sender_type == 'Contact'
    json.author_name replied.sender_type == 'User' ? replied.sender&.name : nil
  end
end

# So existe quando `content_type` e' `input_csat` - a pesquisa de
# satisfacao que o chat manda sozinho ao encerrar (ver `CsatSurveyService`).
if resource.input_csat?
  json.csat_display_type resource.content_attributes['display_type'] || 'emoji'
  json.csat_answered resource.csat_survey_response.present?
end
