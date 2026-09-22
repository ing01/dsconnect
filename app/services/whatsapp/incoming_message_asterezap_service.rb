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
  # com o "9" extra numa, sem nele na proxima. So normalizar pra um formato
  # canonico (primeira tentativa) nao e suficiente: se o contato ja existe
  # no banco gravado no formato "errado" (por ter sido criado antes dessa
  # normalizacao existir, ou por qualquer outra mensagem anterior), a
  # proxima mensagem no formato canonico nunca encontra esse registro e cria
  # um contato/conversa novo por cima - foi exatamente o que aconteceu com
  # "Cesar" (contato 554499577573 x 5544999577573, a mesma pessoa).
  #
  # Por isso a resolucao aqui sempre confere as DUAS formas possiveis contra
  # o que ja existe nesta caixa antes de decidir: a que ja tiver um
  # ContactInbox correspondente vence (preserva o historico), e so cai no
  # formato canonico (com o "9") quando nenhuma das duas existir ainda -
  # contato genuinamente novo.
  PHONE_NORMALIZERS = [
    Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer,
    Whatsapp::PhoneNormalizers::ArgentinaPhoneNormalizer,
    Whatsapp::PhoneNormalizers::MexicoPhoneNormalizer
  ].map(&:new).freeze

  private

  def resolve_phone_for_inbox(raw_phone)
    digits = raw_phone.to_s.gsub(/\D/, '')
    candidates = phone_candidates(digits)
    existing = candidates.find { |candidate| inbox.contact_inboxes.exists?(source_id: candidate) }
    existing || canonical_phone(digits)
  end

  # Devolve as duas grafias possiveis pro mesmo numero brasileiro (com e sem
  # o "9" do celular) - pra numeros de outros paises, so a forma unica.
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
      from: resolve_phone_for_inbox(payload[:phone]),
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
      wa_id: resolve_phone_for_inbox(payload[:phone]),
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
