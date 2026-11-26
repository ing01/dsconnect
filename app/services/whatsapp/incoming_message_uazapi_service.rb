# Traduz o webhook da UAZAPI para o formato generico que
# Whatsapp::IncomingMessageBaseService espera - mesma tecnica do AstereZap e
# do ExpxWhats. Formato da UAZAPI (https://docs.uazapi.com):
#   {"EventType": "messages", "token": "<token da instancia>", "owner": "...",
#    "message": {"id":..., "messageid":"3EB0...", "chatid":"5511...@s.whatsapp.net",
#                "sender_pn":"5511...@s.whatsapp.net", "senderName":"...",
#                "fromMe": false, "isGroup": false, "messageType":"Conversation",
#                "text":"...", "content": {...}, "wasSentByApi": false},
#    "chat": {...}}
#   {"EventType": "messages_update", "type": "ReadReceipt", "state": "Read",
#    "event": {"MessageIDs": ["3EB0..."], "IsFromMe": false, ...}}
class Whatsapp::IncomingMessageUazapiService < Whatsapp::IncomingMessageBaseService
  STATUS_MAP = {
    'delivered' => 'delivered',
    'read' => 'read',
    # Audio "tocado" conta como lido - nao existe status equivalente.
    'played' => 'read'
  }.freeze

  # `messageType` vem no formato do WhatsApp ("Conversation",
  # "ExtendedTextMessage", "ImageMessage"...). O que nao estiver aqui
  # (localizacao, enquete, contato, reacao...) vira "unsupported": fica um
  # aviso na conversa, sem travar o webhook nem criar mensagem vazia.
  MESSAGE_TYPE_MAP = {
    'conversation' => 'text',
    'extendedtext' => 'text',
    'image' => 'image',
    'video' => 'video',
    'audio' => 'audio',
    'ptt' => 'audio',
    'document' => 'document',
    'documentwithcaption' => 'document',
    'sticker' => 'sticker'
  }.freeze

  # Mesma ambiguidade do "9" que o AstereZap ja contorna: o WhatsApp Web pode
  # reportar o mesmo contato brasileiro com e sem o 9. Ver comentario completo
  # em Whatsapp::IncomingMessageAsterezapService.
  PHONE_NORMALIZERS = [
    Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer,
    Whatsapp::PhoneNormalizers::ArgentinaPhoneNormalizer,
    Whatsapp::PhoneNormalizers::MexicoPhoneNormalizer
  ].map(&:new).freeze

  private

  def processed_params
    @processed_params ||= if !authentic_payload?
                             {}
                           elsif status_event?
                             status_processed_params
                           elsif message_event? && processable_message?
                             received_processed_params
                           else
                             {}
                           end
  end

  # A URL do webhook e' so' o numero da caixa - qualquer um que a descobrisse
  # conseguiria injetar mensagem falsa. A UAZAPI manda o token da instancia em
  # todo evento, entao so' aceita o payload se ele bater com o da caixa.
  def authentic_payload?
    expected = inbox.channel.provider_config['token'].to_s
    received = params[:token].to_s
    valid = expected.present? && received.present? && ActiveSupport::SecurityUtils.secure_compare(expected, received)
    Rails.logger.warn("[UAZAPI] webhook com token invalido ignorado (inbox #{inbox.id})") unless valid
    valid
  end

  def status_event?
    params[:EventType] == 'messages_update'
  end

  def message_event?
    params[:EventType] == 'messages'
  end

  # So' conversa individual recebida do contato. `fromMe` (mensagem mandada
  # pelo celular ou pela propria DSConnect) fica de fora pelo mesmo motivo
  # do ExpxWhats: o envio pela DSConnect ja grava o source_id na resposta.
  def processable_message?
    message = params[:message] || {}
    message[:fromMe] != true && message[:isGroup] != true &&
      message[:wasSentByApi] != true && message[:messageid].present?
  end

  def received_processed_params
    { messages: [message_from(params[:message])], contacts: [contact_from(params[:message])] }
  end

  # Recibo que o PROPRIO numero gerou (`IsFromMe`: leu no celular a mensagem
  # do cliente) nao e' status de mensagem enviada - ignora.
  def status_processed_params
    event = params[:event] || {}
    return {} if event[:IsFromMe] == true

    status = STATUS_MAP[params[:state].to_s.downcase]
    ids = Array(event[:MessageIDs])
    return {} if status.blank? || ids.blank?

    { statuses: ids.map { |id| { id: id, status: status, errors: [] } } }
  end

  def message_from(message)
    type = message_content_type(message)
    {
      id: message[:messageid],
      from: resolve_phone_for_inbox(sender_phone(message)),
      type: type
    }.merge(content_field(type, message))
  end

  def sender_phone(message)
    raw = message[:sender_pn].presence || message[:chatid].presence || message[:sender]
    raw.to_s.split('@').first
  end

  def message_content_type(message)
    raw = message[:messageType].to_s.downcase.delete_suffix('message')
    raw = message[:mediaType].to_s.downcase if MESSAGE_TYPE_MAP.exclude?(raw) && message[:mediaType].present?
    MESSAGE_TYPE_MAP.fetch(raw, 'unsupported')
  end

  def content_field(type, message)
    return { text: { body: text_of(message) } } if type == 'text'
    return {} if type == 'unsupported'

    content = message[:content].is_a?(Hash) ? message[:content] : {}
    {
      type.to_sym => {
        id: message[:id].presence || message[:messageid],
        caption: text_of(message).presence || content[:caption].presence,
        filename: content[:fileName].presence || content[:title].presence
      }.compact
    }
  end

  def text_of(message)
    return message[:text].to_s if message[:text].present?

    content = message[:content]
    content.is_a?(Hash) ? content[:text].to_s : content.to_s
  end

  def contact_from(message)
    phone = sender_phone(message)
    chat = params[:chat] || {}
    {
      wa_id: resolve_phone_for_inbox(phone),
      profile: { name: message[:senderName].presence || chat[:wa_name].presence || chat[:name].presence || phone }
    }
  end

  # Midia da UAZAPI nao tem URL fixa: POST /message/download devolve um
  # `fileURL` temporario (2 dias), que e' baixado na hora - por isso nao da'
  # pra usar o `Down.download(media_url)` padrao.
  def download_attachment_file(attachment_payload)
    media = inbox.channel.provider_service.download_media_url(attachment_payload[:id])
    return if media.blank? || media['fileURL'].blank?

    file = Down.download(media['fileURL'])
    filename = attachment_payload[:filename].presence
    file.define_singleton_method(:original_filename) { filename } if filename
    file
  rescue StandardError => e
    Rails.logger.error("[UAZAPI] download de midia falhou: #{e.message}")
    nil
  end

  def resolve_phone_for_inbox(raw_phone)
    digits = raw_phone.to_s.gsub(/\D/, '')
    candidates = phone_candidates(digits)
    existing = candidates.find { |candidate| inbox.contact_inboxes.exists?(source_id: candidate) }
    existing || canonical_phone(digits)
  end

  def phone_candidates(digits)
    return [canonical_phone(digits)] unless digits.start_with?('55') && [12, 13].include?(digits.length)

    ddd = digits[2, 2]
    local = digits[4..]
    with_nine = local.length == 9 ? local : "9#{local}"
    without_nine = local.length == 9 && local.start_with?('9') ? local[1..] : local

    ["55#{ddd}#{with_nine}", "55#{ddd}#{without_nine}"].uniq
  end

  def canonical_phone(digits)
    normalizer = PHONE_NORMALIZERS.find { |candidate| candidate.handles_country?(digits) }
    return digits if normalizer.blank?

    normalizer.normalize(digits)
  end
end
