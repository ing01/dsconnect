# Gateway ExpxWhats (auto-hospedado, https://github.com/.../ExpxWhats) - API
# Go sobre a biblioteca whatsmeow. Mesma familia do AstereZap
# (Whatsapp::Providers::WhatsappAsterezapService): uma sessao comum de
# WhatsApp Web pareada por QR code, nao a WhatsApp Business Platform oficial
# da Meta - sem "template aprovado" nem janela de 24h. Ver
# docs/whatsapp_expxwhats_setup.md para o passo a passo completo (como
# instalar, parear o numero e configurar o webhook).
#
# Diferente do AstereZap, o ExpxWhats e' rodado pela propria empresa (nao um
# servico de terceiros) - por isso o provider_config carrega `base_url`
# (endereco onde o `wapi` esta rodando) em vez de uma URL fixa.
class Whatsapp::Providers::WhatsappExpxwhatsService < Whatsapp::Providers::BaseService
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
    # Nao existe endpoint de templates no ExpxWhats.
  end

  # Confere as credenciais de verdade (ao contrario do AstereZap, que nao tem
  # endpoint leve pra isso): GET /config so' le a configuracao da instancia,
  # sem efeito colateral, e falha com 401/404 se base_url/instance/token
  # estiverem errados.
  def validate_provider_config?
    config = whatsapp_channel.provider_config
    return false if config['base_url'].blank? || config['instance_name'].blank? || config['token'].blank?

    response = HTTParty.get("#{instance_path}/config", headers: api_headers, timeout: 10)
    response.success?
  rescue StandardError => e
    Rails.logger.warn("[ExpxWhats] validate_provider_config? falhou: #{e.message}")
    false
  end

  def api_headers
    { 'Content-Type' => 'application/json', 'X-Instance-Token' => whatsapp_channel.provider_config['token'] }
  end

  def media_url(message_id)
    "#{instance_path}/messages/#{message_id}/media"
  end

  private

  # Mesmo motivo do AstereZap: WhatsApp Web marca como suspeito um numero que
  # responde tudo instantaneo, sem intervalo humano nenhum - risco real de
  # banimento. O ExpxWhats ja tem suporte nativo a "digitando" embutido no
  # envio (`typing_ms` no corpo de /messages), entao nao precisamos do sleep
  # manual que o AstereZap exige - so' calculamos a duracao e mandamos junto.
  #
  # Configuravel por inbox (Configuracoes da caixa de entrada > aba
  # Configuracoes, `provider_config['typing_delay_min_seconds']` /
  # `['typing_delay_max_seconds']`), mesma config que o AstereZap ja usa -
  # pedido da Ingrid, 2026-11-13: "tomando cuidado para evitar ao maximo o
  # banimento do numero".
  DEFAULT_MIN_TYPING_DELAY_SECONDS = 1.5
  DEFAULT_MAX_TYPING_DELAY_SECONDS = 12.0
  CHARACTERS_TYPED_PER_SECOND = 12.0
  MAX_TYPING_MS = 15_000

  def instance_path
    config = whatsapp_channel.provider_config
    "#{config['base_url'].to_s.chomp('/')}/instances/#{config['instance_name']}"
  end

  def send_text_message(phone_number, message)
    body_text = outgoing_content_with_agent_name(message)

    response = HTTParty.post(
      "#{instance_path}/messages",
      headers: api_headers,
      body: { to: phone_number, type: 'text', text: body_text, typing_ms: typing_ms_for(body_text) }.to_json
    )

    process_response(response, message)
  end

  # A mensagem do Chatwoot pode levar varios anexos de uma vez, mas cada
  # chamada ao ExpxWhats so aceita UM arquivo por envio - mesmo loop que o
  # AstereZap ja usa. O `source_id` gravado na mensagem fica sendo o do
  # primeiro envio que deu certo.
  def send_attachment_message(phone_number, message)
    first_source_id = nil
    message.attachments.each_with_index do |attachment, index|
      source_id = send_single_attachment(phone_number, message, attachment, caption: index.zero?)
      first_source_id ||= source_id
    end
    first_source_id
  end

  def send_single_attachment(phone_number, message, attachment, caption:)
    type = attachment_message_type(attachment)
    caption_text = caption && %w[audio voice sticker].exclude?(type) ? outgoing_content_with_agent_name(message) : nil

    body = { to: phone_number, type: type, url: attachment.download_url }
    body[:caption] = caption_text if caption_text.present?
    body[:filename] = attachment.file.filename.to_s if type == 'document'
    body[:typing_ms] = typing_ms_for(caption_text || '') if caption

    response = HTTParty.post(
      "#{instance_path}/messages",
      headers: api_headers,
      body: body.to_json
    )

    process_response(response, message)
  end

  def typing_ms_for(content)
    min_delay = min_typing_delay_seconds
    max_delay = [max_typing_delay_seconds, min_delay].max
    variable_part = content.to_s.length / CHARACTERS_TYPED_PER_SECOND
    seconds = (min_delay + rand + variable_part).clamp(min_delay, max_delay)
    (seconds * 1000).to_i.clamp(0, MAX_TYPING_MS)
  end

  def min_typing_delay_seconds
    whatsapp_channel.provider_config['typing_delay_min_seconds'].presence&.to_f || DEFAULT_MIN_TYPING_DELAY_SECONDS
  end

  def max_typing_delay_seconds
    whatsapp_channel.provider_config['typing_delay_max_seconds'].presence&.to_f || DEFAULT_MAX_TYPING_DELAY_SECONDS
  end

  # Mesma deteccao de nota de voz que Whatsapp::Providers::WhatsappCloudAttachmentSender
  # ja usa (`attachment.meta['is_voice_message']` + mimetype ogg).
  def attachment_message_type(attachment)
    file_type = attachment.file_type
    return 'voice' if file_type == 'audio' && attachment.meta&.dig('is_voice_message') && attachment.file.content_type == 'audio/ogg'
    return file_type if %w[image audio video].include?(file_type)

    'document'
  end

  # Resposta do ExpxWhats (POST /messages) vem achatada: {"id":"...",
  # "to":"...", "timestamp":..., "kind":"..."} no 200, sem o formato
  # {"messages":[{"id":...}]} que o BaseService assume (isso e formato
  # Meta/360dialog).
  def process_response(response, message)
    parsed = response.parsed_response
    if response.success? && parsed.is_a?(Hash) && parsed['id'].present?
      parsed['id']
    else
      handle_error(response, message)
      nil
    end
  end

  # Prefixa o nome de quem enviou - mesma regra do AstereZap (sem isso, a
  # mensagem parece vir de um numero anonimo, nao de uma pessoa da equipe).
  def outgoing_content_with_agent_name(message)
    content = message.outgoing_content.to_s
    agent_name = agent_name_for(message)

    return content if agent_name.blank?
    return content if content.start_with?("*#{agent_name}:*")

    "*#{agent_name}:*\n#{content}"
  end

  def agent_name_for(message)
    sender = message.sender
    return nil unless sender.is_a?(User)

    sender.name.presence
  end

  # Corpo de erro do ExpxWhats e' sempre {"error":"mensagem"} (ver `fail()` no
  # servidor Go) - formato unico, diferente do AstereZap que varia por status.
  def error_message(response)
    parsed = response.parsed_response
    return response.message unless parsed.is_a?(Hash)

    parsed['error'].presence || response.message
  end
end
