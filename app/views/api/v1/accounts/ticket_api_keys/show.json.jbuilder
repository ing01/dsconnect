json.exists @ticket_api_key.present?

if @ticket_api_key
  json.last_used_at @ticket_api_key.last_used_at&.iso8601
  token = @ticket_api_key.token
  json.masked_token "#{'*' * [token.length - 4, 0].max}#{token.last(4)}"
  # So' na resposta do `create` - dali em diante a chave de verdade nunca mais
  # volta pela API, so a versao mascarada acima.
  json.token token if local_assigns[:reveal_token]
end
