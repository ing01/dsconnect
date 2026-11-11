json.id resource.id
json.message resource.message
json.message_type resource.message_type
json.created_at resource.created_at.to_i
json.copilot_thread resource.copilot_thread.push_event_data
json.account_id resource.account_id
# A avaliacao da pessoa logada para esta resposta (nil se ainda nao avaliou). Le da
# associacao ja carregada: a listagem faz o preload, sem uma consulta por mensagem.
mine = resource.copilot_message_feedbacks.find { |feedback| feedback.user_id == Current.user&.id }
json.feedback(mine && { rating: mine.rating, reason: mine.reason, comment: mine.comment })
