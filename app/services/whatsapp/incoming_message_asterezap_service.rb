# Traduz o payload de webhook do AstereZap (zap.astere.com.br) para o formato
# generico que Whatsapp::IncomingMessageBaseService espera - a mesma tecnica
# usada por Whatsapp::IncomingMessageWhatsappCloudService pra desembrulhar o
# envelope da Meta, so que pro formato "achatado" do AstereZap:
#   {"type": "ReceivedCallback", "phone": "...", "messageId": "...",
#    "text": {"message": "..."}} (ou "image"/"audio"/"document"/"video" no
#    lugar de "text", pra mensagem com midia)
class Whatsapp::IncomingMessageAsterezapService < Whatsapp::IncomingMessageBaseService
  STATUS_MAP = {
    'SENT' => 'sent',
    'DELIVERED' => 'delivered',
    'READ' => 'read',
    'FAILED' => 'failed',
    'ERROR' => 'failed'
  }.freeze

  # WhatsApp Web (o que o AstereZap automatiza) as vezes reporta o mesmo
  # contato brasileiro em formatos diferentes entre uma mensagem e outra -
  # com o "9" extra numa, sem nele na proxima. Chatwoot ja tem
  # Whatsapp::PhoneNumberNormalizationService pra isso, mas ele so acha um
  # contato existente se o formato ja tiver sido normalizado antes (nao
  # ajuda na primeira mensagem de um contato novo). Normalizando aqui, antes
  # do numero virar `from`/`wa_id`, toda mensagem do mesmo numero cai sempre
  # no mesmo formato - o que evitou o bug real: 3 mensagens do mesmo cliente
  # viraram 2 contatos/conversas diferentes.
  PHONE_NORMALIZERS = [
    Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer,
    Whatsapp::PhoneNormalizers::ArgentinaPhoneNormalizer,
    Whatsapp::PhoneNormalizers::MexicoPhoneNormalizer
  ].map(&:new).freeze

  private

  def canonical_phone(raw_phone)
    digits = raw_phone.to_s.gsub(/\D/, '')
    normalizer = PHONE_NORMALIZERS.find { |candidate| candidate.handles_country?(digits) }
    return digits if normalizer.blank?

    normalizer.normalize(digits)
  end

  def processed_params
    @processed_params ||= if status_event?
                             status_processed_params
                           elsif params[:messageId].present?
                             received_processed_params
                           else
                             {}
                           end
  end

  def status_event?
    params[:type] == 'MessageStatusCallback'
  end

  def received_processed_params
    { messages: [message_from(params)], contacts: [contact_from(params)] }
  end

  # O nome exato do campo de status dentro do MessageStatusCallback nao esta
  # confirmado na documentacao publica - fica tolerante de proposito: se nao
  # der pra montar um status reconhecido, devolve vazio (o `perform` da base
  # simplesmente nao faz nada) em vez de arriscar `message.status = nil` e
  # `save!` levantando um erro nao tratado no meio do processamento do webhook.
  def status_processed_params
    status = status_from(params)
    return {} if status.blank?

    { statuses: [status] }
  end

  def status_from(payload)
    message_id = payload[:messageId] || payload.dig(:data, :key, :id)
    status = normalize_status(payload[:status] || payload.dig(:data, :status))
    return nil if message_id.blank? || status.blank?

    { id: message_id, status: status, errors: [] }
  end

  def normalize_status(raw_status)
    STATUS_MAP[raw_status.to_s.upcase]
  end

  def message_from(payload)
    type = message_content_type(payload)
    {
      id: payload[:messageId],
      from: canonical_phone(payload[:phone]),
      type: type
    }.merge(content_field(type, payload))
  end

  # O `type` no topo do payload ("ReceivedCallback") e o tipo do evento, nao
  # do conteudo - o tipo da mensagem e' inferido por qual campo veio
  # preenchido (so um deles vem por mensagem).
  def message_content_type(payload)
    return 'image' if payload[:image].present?
    return 'audio' if payload[:audio].present?
    return 'document' if payload[:document].present?
    return 'video' if payload[:video].present?

    'text'
  end

  def content_field(type, payload)
    return { text: { body: payload.dig(:text, :message).to_s } } if type == 'text'

    media_payload = payload[type.to_sym] || {}
    {
      type.to_sym => {
        id: payload[:messageId],
        caption: media_payload[:caption],
        filename: media_payload[:fileName]
      }.compact
    }
  end

  def contact_from(payload)
    {
      wa_id: canonical_phone(payload[:phone]),
      profile: { name: payload[:pushName].presence || payload[:phone] }
    }
  end

  # O endpoint de midia do AstereZap devolve um envelope JSON com base64
  # (nao uma URL baixavel direto como no 360dialog), entao nao da pra
  # reaproveitar o `Down.download` default de IncomingMessageServiceHelpers.
  def download_attachment_file(attachment_payload)
    response = HTTParty.get(inbox.channel.media_url(attachment_payload[:id]), headers: inbox.channel.api_headers)
    return unless response.success?

    body = response.parsed_response
    decoded = Base64.decode64(body['base64'].to_s)
    filename = attachment_payload[:filename].presence || body['fileName']
    content_type = body['mimeType']

    file = StringIO.new(decoded)
    file.define_singleton_method(:original_filename) { filename }
    file.define_singleton_method(:content_type) { content_type }
    file
  end
end
