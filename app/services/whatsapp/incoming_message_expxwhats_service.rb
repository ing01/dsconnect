# Traduz o payload de webhook do ExpxWhats para o formato generico que
# Whatsapp::IncomingMessageBaseService espera - mesma tecnica de
# Whatsapp::IncomingMessageAsterezapService, pro formato do ExpxWhats:
#   {"instance": "nome", "event": "message"|"receipt", "time": 123,
#    "data": {"id":..., "chat":"5521...@s.whatsapp.net", "sender_pn":"5521...",
#             "sender_name":"...", "from_me": false, "kind": "text"|"image"|...,
#             "text": "...", "is_group": false, ...}}
#
# O download de midia NAO precisa de override: o endpoint
# /messages/{id}/media do ExpxWhats ja devolve o arquivo binario com o
# Content-Type certo, entao o `Down.download` padrao (ver
# Whatsapp::IncomingMessageServiceHelpers#download_attachment_file) funciona
# direto - diferente do AstereZap, que embrulha a midia em JSON+base64.
class Whatsapp::IncomingMessageExpxwhatsService < Whatsapp::IncomingMessageBaseService
  STATUS_MAP = {
    'delivered' => 'delivered',
    'read' => 'read',
    # Nota de voz "tocada" conta como lida pro Chatwoot - nao existe um
    # status intermediario equivalente.
    'played' => 'read'
  }.freeze

  # Tipos que o ExpxWhats manda com midia/texto suficiente pra montar a
  # mensagem direito. O resto (localizacao, enquete, contato, chamada
  # perdida, etc.) vira "unsupported" - mesmo tratamento que
  # IncomingMessageBaseService ja da' pra tipos que a Meta manda sem
  # conseguir renderizar: fica um placeholder na conversa, sem travar o
  # processamento do webhook nem criar uma mensagem vazia.
  SUPPORTED_KINDS = %w[text image video audio voice document sticker].freeze

  # Mesma ambiguidade do "9" que o AstereZap ja tinha que contornar: o
  # whatsmeow tambem pode reportar o mesmo contato brasileiro em formatos
  # diferentes entre uma mensagem e outra. Ver comentario completo em
  # Whatsapp::IncomingMessageAsterezapService.
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
                           elsif message_event? && processable_message?
                             received_processed_params
                           else
                             {}
                           end
  end

  def status_event?
    params[:event] == 'receipt'
  end

  def message_event?
    params[:event] == 'message'
  end

  # So processa mensagem individual (nao grupo) recebida do contato - o
  # eco das mensagens que a propria DSConnect mandou (from_me: true) ja'
  # chega com o source_id certo na resposta sincrona do envio
  # (Whatsapp::Providers::WhatsappExpxwhatsService#process_response), entao
  # reprocessar o evento aqui so criaria uma mensagem duplicada.
  def processable_message?
    data = params[:data] || {}
    data[:from_me] != true && data[:is_group] != true && data[:id].present?
  end

  def received_processed_params
    { messages: [message_from(params[:data])], contacts: [contact_from(params[:data])] }
  end

  def status_processed_params
    data = params[:data] || {}
    status = STATUS_MAP[data[:status].to_s]
    ids = Array(data[:ids])
    return {} if status.blank? || ids.blank?

    { statuses: ids.map { |id| { id: id, status: status, errors: [] } } }
  end

  def message_from(data)
    type = message_content_type(data[:kind])
    {
      id: data[:id],
      from: resolve_phone_for_inbox(sender_phone(data)),
      type: type
    }.merge(content_field(type, data))
  end

  def sender_phone(data)
    data[:sender_pn].presence || data[:sender].to_s.split('@').first
  end

  def message_content_type(kind)
    SUPPORTED_KINDS.include?(kind.to_s) ? kind.to_s : 'unsupported'
  end

  def content_field(type, data)
    return { text: { body: data[:text].to_s } } if type == 'text'
    return {} if type == 'unsupported'

    {
      type.to_sym => {
        id: data[:id],
        caption: data[:text].presence,
        filename: data[:filename].presence
      }.compact
    }
  end

  def contact_from(data)
    {
      wa_id: resolve_phone_for_inbox(sender_phone(data)),
      profile: { name: data[:sender_name].presence || data[:chat_name].presence || sender_phone(data) }
    }
  end
end
