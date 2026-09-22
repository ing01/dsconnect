# Gateway AstereZap (zap.astere.com.br) - embrulha o Evolution API no estilo
# Z-API: sem header de autenticacao, instance_id/token vao no caminho da URL.
# Nao e a WhatsApp Business Platform oficial (e uma sessao de WhatsApp comum,
# pareada por QR code no painel do AstereZap), entao nao existe o conceito de
# "template aprovado" nem a janela de 24h de atendimento da Meta.
class Whatsapp::Providers::WhatsappAsterezapService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  # Sem templates aprovados aqui - manda como mensagem de texto normal.
  def send_template(phone_number, _template_info, message)
    send_text_message(phone_number, message)
  end

  def sync_templates
    # Nao existe endpoint de templates no AstereZap.
  end

  # Sem chamada remota: a doc nao expoe um endpoint leve de status da
  # instancia sem efeito colateral. So confere que as credenciais vieram
  # preenchidas - a validacao de verdade acontece no primeiro envio.
  def validate_provider_config?
    whatsapp_channel.provider_config['instance_id'].present? &&
      whatsapp_channel.provider_config['token'].present?
  end

  def api_headers
    { 'Content-Type' => 'application/json' }
  end

  def media_url(media_id)
    "#{instance_path}/media/#{media_id}"
  end

  private

  # WhatsApp Web (o que o AstereZap automatiza por baixo) marca como suspeito
  # um numero que responde tudo instantaneo, sem intervalo humano nenhum -
  # risco real de banimento/limitacao, diferente da Business Platform oficial
  # da Meta (que nao tem esse problema). Por isso todo envio espera um tempo
  # proporcional ao tamanho da mensagem antes de postar, simulando alguem
  # digitando.
  MIN_TYPING_DELAY_SECONDS = 1.5
  MAX_TYPING_DELAY_SECONDS = 12.0
  CHARACTERS_TYPED_PER_SECOND = 12.0

  def api_base_path
    ENV.fetch('ASTEREZAP_BASE_URL', 'https://zap.astere.com.br/v1')
  end

  def instance_path
    config = whatsapp_channel.provider_config
    "#{api_base_path}/instances/#{config['instance_id']}/token/#{config['token']}"
  end

  def send_text_message(phone_number, message)
    simulate_typing(phone_number, message.outgoing_content)

    response = HTTParty.post(
      "#{instance_path}/send-text",
      headers: api_headers,
      body: { phone: phone_number, message: message.outgoing_content }.to_json
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    type = attachment_endpoint_type(attachment.file_type)

    simulate_typing(phone_number, message.outgoing_content)

    body = { phone: phone_number, type.to_sym => attachment.download_url }
    body['caption'] = message.outgoing_content if type != 'audio' && message.outgoing_content.present?
    body['fileName'] = attachment.file.filename.to_s if type == 'document'

    response = HTTParty.post(
      "#{instance_path}/send-#{type}",
      headers: api_headers,
      body: body.to_json
    )

    process_response(response, message)
  end

  def simulate_typing(phone_number, content)
    duration = typing_duration_for(content)
    notify_typing(phone_number, duration)
    sleep(duration)
  end

  def typing_duration_for(content)
    variable_part = content.to_s.length / CHARACTERS_TYPED_PER_SECOND
    (MIN_TYPING_DELAY_SECONDS + rand + variable_part).clamp(MIN_TYPING_DELAY_SECONDS, MAX_TYPING_DELAY_SECONDS)
  end

  # Indicador visual de "digitando..." - melhor esforco, so. O formato exato
  # do send-presence nao esta confirmado na documentacao publica do AstereZap,
  # entao qualquer falha aqui e' ignorada sem afetar o envio de verdade: quem
  # protege contra banimento e' o `sleep` em `simulate_typing`, nao isto.
  def notify_typing(phone_number, duration)
    HTTParty.post(
      "#{instance_path}/send-presence",
      headers: api_headers,
      body: { phone: phone_number, presence: 'composing', delay: (duration * 1000).to_i }.to_json,
      timeout: 5
    )
  rescue StandardError => e
    Rails.logger.warn("[AstereZap] send-presence falhou: #{e.message}")
  end

  def attachment_endpoint_type(file_type)
    return file_type if %w[image audio video].include?(file_type)

    'document'
  end

  # Resposta do AstereZap nao segue o formato {"messages":[{"id":...}]} que o
  # BaseService assume (isso e formato Meta/360dialog) - vem achatada:
  # {"messageId":..., "zaapId":..., "id":...} no 201, com "queued": true no 202.
  def process_response(response, message)
    parsed = response.parsed_response
    if response.success? && parsed.is_a?(Hash) && parsed['messageId'].present?
      parsed['messageId']
    else
      handle_error(response, message)
      nil
    end
  end

  # Corpo de erro varia por status: 400 traz {statusCode, message: [...], error},
  # 403/404/502/503 trazem {error: "CODIGO", value: ...}. Tenta os formatos
  # conhecidos em vez de assumir um so.
  def error_message(response)
    parsed = response.parsed_response
    return response.message unless parsed.is_a?(Hash)

    Array(parsed['message']).join(', ').presence || parsed['error'] || response.message
  end
end
