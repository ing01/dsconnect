class Whatsapp::Providers::Whatsapp360DialogService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(phone_number, template_info, message)
    response = HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: {
        to: phone_number,
        template: template_body_parameters(template_info),
        type: 'template'
      }.to_json
    )

    process_response(response, message)
  end

  def sync_templates
    # ensuring that channels with wrong provider config wouldn't keep trying to sync templates
    whatsapp_channel.mark_message_templates_updated
    response = HTTParty.get("#{api_base_path}/configs/templates", headers: api_headers)
    whatsapp_channel.update(message_templates: response['waba_templates'], message_templates_last_updated: Time.now.utc) if response.success?
  end

  def validate_provider_config?
    response = HTTParty.post(
      "#{api_base_path}/configs/webhook",
      headers: { 'D360-API-KEY': whatsapp_channel.provider_config['api_key'], 'Content-Type': 'application/json' },
      body: {
        url: "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/whatsapp/#{whatsapp_channel.phone_number}"
      }.to_json
    )
    response.success?
  end

  def api_headers
    { 'D360-API-KEY' => whatsapp_channel.provider_config['api_key'], 'Content-Type' => 'application/json' }
  end

  def media_url(media_id)
    "#{api_base_path}/media/#{media_id}"
  end

  private

  def api_base_path
    # provide the environment variable when testing against sandbox : 'https://waba-sandbox.360dialog.io/v1'
    ENV.fetch('360DIALOG_BASE_URL', 'https://waba.360dialog.io/v1')
  end

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: {
        to: phone_number,
        text: { body: message.outgoing_content },
        type: 'text'
      }.to_json
    )

    process_response(response, message)
  end

  # A mensagem do Chatwoot pode levar varios anexos de uma vez (ver tela de
  # composicao), mas a API do 360dialog so aceita UM midia por chamada - sem
  # este loop, so o primeiro anexo saia e os demais eram descartados em
  # silencio. O `source_id` gravado na mensagem fica sendo o do primeiro envio
  # que deu certo, que e' o unico que cabe no campo (uma coluna, um id).
  def send_attachment_message(phone_number, message)
    first_source_id = nil
    message.attachments.each_with_index do |attachment, index|
      source_id = send_single_attachment(phone_number, message, attachment, caption: index.zero?)
      first_source_id ||= source_id
    end
    first_source_id
  end

  def send_single_attachment(phone_number, message, attachment, caption:)
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    type_content = {
      'link': attachment.download_url
    }
    type_content['caption'] = message.outgoing_content if caption && %w[audio sticker].exclude?(type)
    type_content['filename'] = attachment.file.filename if type == 'document'

    response = HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: {
        'to' => phone_number,
        'type' => type,
        type.to_s => type_content
      }.to_json
    )

    process_response(response, message)
  end

  def error_message(response)
    # {"meta": {"success": false, "http_code": 400, "developer_message": "errro-message", "360dialog_trace_id": "someid"}}
    response.parsed_response.dig('meta', 'developer_message')
  end

  def template_body_parameters(template_info)
    {
      name: template_info[:name],
      namespace: template_info[:namespace],
      language: {
        policy: 'deterministic',
        code: template_info[:lang_code]
      },
      components: template_info[:parameters]
    }
  end

  def send_interactive_text_message(phone_number, message)
    payload = create_payload_based_on_items(message)

    response = HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: {
        to: phone_number,
        interactive: payload,
        type: 'interactive'
      }.to_json
    )

    process_response(response, message)
  end
end
