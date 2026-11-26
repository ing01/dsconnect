# Gateway UAZAPI (uazapiGO, https://docs.uazapi.com) - mesma familia do
# AstereZap e do ExpxWhats: uma sessao comum de WhatsApp Web pareada por QR
# code, nao a WhatsApp Business Platform oficial da Meta - sem "template
# aprovado" nem janela de 24h. Ver docs/whatsapp_uazapi_setup.md.
#
# provider_config:
#   base_url - endereco do servidor (ex: https://suaempresa.uazapi.com)
#   token    - token da INSTANCIA (header `token`). O admintoken do servidor
#              nunca fica gravado aqui: ele so' serve pra criar instancias, e
#              quem tivesse acesso a caixa de entrada controlaria todos os
#              numeros do servidor.
class Whatsapp::Providers::WhatsappUazapiService < Whatsapp::Providers::BaseService
  # Eventos que a DSConnect precisa receber. `wasSentByApi` fica de fora: a
  # mensagem que a propria DSConnect mandou ja tem o source_id gravado pela
  # resposta do envio, e o eco so' duplicaria.
  WEBHOOK_EVENTS = %w[messages messages_update connection].freeze
  WEBHOOK_EXCLUDED_MESSAGES = %w[wasSentByApi].freeze

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
    # Nao existe endpoint de templates na UAZAPI.
  end

  # GET /instance/status so' le o estado da instancia, e responde 401 se o
  # token nao existe naquele servidor - confere endereco + token de verdade
  # antes de criar o canal.
  def validate_provider_config?
    config = whatsapp_channel.provider_config
    return false if config['base_url'].blank? || config['token'].blank?

    HTTParty.get("#{base_url}/instance/status", headers: api_headers, timeout: 10).success?
  rescue StandardError => e
    Rails.logger.warn("[UAZAPI] validate_provider_config? falhou: #{e.message}")
    false
  end

  def api_headers
    { 'Content-Type' => 'application/json', 'token' => whatsapp_channel.provider_config['token'].to_s }
  end

  # A midia recebida nao tem URL fixa: POST /message/download devolve um
  # `fileURL` temporario (vale 2 dias). Quem baixa e'
  # Whatsapp::IncomingMessageUazapiService#download_attachment_file.
  def media_url(_message_id)
    "#{base_url}/message/download"
  end

  def download_media_url(message_id)
    response = HTTParty.post(
      media_url(message_id),
      headers: api_headers,
      body: { id: message_id, return_link: true }.to_json,
      timeout: 30
    )
    return unless response.success? && response.parsed_response.is_a?(Hash)

    response.parsed_response.slice('fileURL', 'mimetype')
  end

  # Aponta o webhook da instancia pra DSConnect logo que a caixa e' criada,
  # sem a pessoa precisar configurar no painel da UAZAPI. POST /webhook e'
  # idempotente (substitui a configuracao), entao rodar de novo e' seguro.
  def setup_webhook!(url)
    response = HTTParty.post(
      "#{base_url}/webhook",
      headers: api_headers,
      body: {
        enabled: true,
        url: url,
        events: WEBHOOK_EVENTS,
        excludeMessages: WEBHOOK_EXCLUDED_MESSAGES
      }.to_json,
      timeout: 15
    )
    Rails.logger.error("[UAZAPI] configurar webhook falhou: #{response.code} #{response.body}") unless response.success?
    response.success?
  end

  private

  # Mesmo motivo do AstereZap/ExpxWhats: WhatsApp Web marca como suspeito um
  # numero que responde tudo instantaneo. A UAZAPI tem o "digitando" embutido
  # no proprio envio (`delay` em ms: mostra "Digitando..." e so' entao manda),
  # entao basta calcular a duracao - mesma config por caixa dos outros dois.
  DEFAULT_MIN_TYPING_DELAY_SECONDS = 1.5
  DEFAULT_MAX_TYPING_DELAY_SECONDS = 12.0
  CHARACTERS_TYPED_PER_SECOND = 12.0
  MAX_TYPING_MS = 15_000

  def base_url
    whatsapp_channel.provider_config['base_url'].to_s.strip.chomp('/')
  end

  def send_text_message(phone_number, message)
    body_text = outgoing_content_with_agent_name(message)

    response = HTTParty.post(
      "#{base_url}/send/text",
      headers: api_headers,
      body: { number: phone_number, text: body_text, delay: typing_ms_for(body_text) }.to_json
    )

    process_response(response, message)
  end

  # Cada chamada a /send/media leva UM arquivo - mesmo loop dos outros
  # providers nao oficiais. A legenda e o "digitando" vao so' no primeiro.
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
    caption_text = caption && %w[audio ptt].exclude?(type) ? outgoing_content_with_agent_name(message) : nil

    body = { number: phone_number, type: type, file: attachment_base64(attachment), mimetype: attachment.file.content_type }
    body[:text] = caption_text if caption_text.present?
    body[:docName] = attachment.file.filename.to_s if type == 'document'
    body[:delay] = typing_ms_for(caption_text.to_s) if caption

    response = HTTParty.post(
      "#{base_url}/send/media",
      headers: api_headers,
      body: body.to_json
    )

    process_response(response, message)
  end

  # O arquivo vai DENTRO da requisicao, em base64, e nao como link pra UAZAPI
  # baixar: o link do ActiveStorage (`download_url`) respondeu 401 pro
  # servidor da UAZAPI em producao (2026-11-26), e mesmo quando abre ele
  # expira em 5 minutos. Testado ao vivo: link -> 500 "HTTP 401", base64 -> 200.
  def attachment_base64(attachment)
    Base64.strict_encode64(attachment.file.download)
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

  # Nota de voz gravada na DSConnect vai como `ptt` (aparece como audio
  # gravado no celular do cliente); outro audio vai como arquivo de audio.
  # Mesma deteccao do WhatsappCloudAttachmentSender.
  def attachment_message_type(attachment)
    file_type = attachment.file_type
    return 'ptt' if file_type == 'audio' && attachment.meta&.dig('is_voice_message')
    return file_type if %w[image audio video].include?(file_type)

    'document'
  end

  # A resposta traz dois ids: `id` (interno da UAZAPI) e `messageid` (o id
  # do proprio WhatsApp). Grava o `messageid`, porque e' ele que volta nos
  # recibos de entrega/leitura (`MessageIDs` do evento messages_update) - com
  # o outro, o status da mensagem nunca sairia de "enviado".
  def process_response(response, message)
    parsed = response.parsed_response
    source_id = parsed['messageid'].presence || parsed['id'].presence if parsed.is_a?(Hash)

    if response.success? && source_id.present?
      source_id.to_s
    else
      handle_error(response, message)
      nil
    end
  end

  # Prefixa o nome de quem enviou - mesma regra do AstereZap/ExpxWhats.
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

  # Erros da UAZAPI vem como {"error": "..."} (401/400) ou, nos envios
  # recusados pelo WhatsApp, com `error_key` (ex: WHATSAPP_REACHOUT_TIMELOCK).
  def error_message(response)
    parsed = response.parsed_response
    return response.message unless parsed.is_a?(Hash)

    parsed['error'].presence || parsed['message'].presence || parsed['error_key'].presence || response.message
  end
end
