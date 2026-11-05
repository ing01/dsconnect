# Envio de anexos do WhatsappCloudService, isolado para o arquivo principal
# nao estourar o limite de linhas por classe (Metrics/ClassLength).
#
# A mensagem do Chatwoot pode levar varios anexos de uma vez (ver tela de
# composicao), mas a API do WhatsApp so aceita UM midia por chamada - sem o
# loop em `send_attachment_message`, so o primeiro anexo saia e os demais
# eram descartados em silencio. O `source_id` gravado na mensagem fica sendo
# o do primeiro envio que deu certo, que e' o unico que cabe no campo (uma
# coluna, um id).
module Whatsapp::Providers::WhatsappCloudAttachmentSender
  private

  def send_attachment_message(phone_number, message)
    first_source_id = nil
    message.attachments.each_with_index do |attachment, index|
      source_id = send_single_attachment(phone_number, message, attachment, caption: index.zero?)
      first_source_id ||= source_id
    end
    first_source_id
  end

  def send_single_attachment(phone_number, message, attachment, caption:)
    normalize_opus_content_type(attachment)
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    type_content = build_attachment_content(type, attachment, message, caption: caption)
    response = HTTParty.post(
      "#{phone_id_path('v24.0')}/messages",
      headers: api_headers,
      body: {
        :messaging_product => 'whatsapp',
        :context => whatsapp_reply_context(message),
        **recipient_params(phone_number),
        'type' => type,
        type.to_s => type_content
      }.to_json
    )

    process_response(response, message)
  end

  def voice_message?(type, attachment)
    type == 'audio' && attachment.meta&.dig('is_voice_message') && attachment.file.content_type == 'audio/ogg'
  end

  # Marcel gem may re-detect OGG/Opus files as audio/opus after ActiveStorage
  # blob attachment, but WhatsApp Cloud API requires audio/ogg content type
  # for voice messages. Normalize so the download URL serves the correct
  # Content-Type header. No-op when the frontend already uploads as audio/ogg.
  def normalize_opus_content_type(attachment)
    return unless attachment.file.attached?

    blob = attachment.file.blob
    return unless blob.content_type == 'audio/opus'

    return if blob.update(content_type: 'audio/ogg')

    Rails.logger.error("Failed to normalize blob #{blob.id} content_type from audio/opus to audio/ogg")
  end

  # `caption:` so' vai true no PRIMEIRO anexo de uma mensagem com varios -
  # repetir `message.outgoing_content` em cada um faria o texto chegar
  # duplicado uma vez por arquivo no WhatsApp do cliente.
  def build_attachment_content(type, attachment, message, caption: true)
    type_content = { 'link' => attachment.download_url }
    type_content['caption'] = message.outgoing_content if caption && %w[audio sticker].exclude?(type)
    type_content['filename'] = attachment.file.filename if type == 'document'
    type_content['voice'] = true if voice_message?(type, attachment)
    type_content
  end
end
