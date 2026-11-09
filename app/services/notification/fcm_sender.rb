# Envia UMA mensagem FCM e le a RESPOSTA do Google - o que os dois caminhos de push
# (colaborador: Notification::PushNotificationService; cliente:
# Client::PushNotificationDeliverable) faziam so' pela metade.
#
# O que existia olhava `results` no corpo, que e' o formato da API LEGADA. A API v1
# (a que o gem usa em `send_v1`) responde erro em `error`, com o HTTP 4xx/5xx. Resultado:
# TODA falha de entrega passava por sucesso e sumia sem log - o iPhone sem chave de APNs
# no Firebase (`THIRD_PARTY_AUTH_ERROR`) e o token de um app desinstalado (`UNREGISTERED`)
# eram invisiveis, e o token morto ficava para sempre na tabela.
#
# Agora cada resposta vira uma de quatro coisas:
#   - entregue ......................... log de info;
#   - token morto (app desinstalado, ou
#     token de outro projeto) ........... a inscricao e' removida - nao ha como recuperar;
#   - falha de autenticacao no APNs/Web
#     Push (`THIRD_PARTY_AUTH_ERROR`) ... log de ERRO + rastreador de excecoes, e a
#     inscricao FICA: o token e' bom, quem esta errado e' a chave no Firebase;
#   - qualquer outra (cota, instabilidade
#     do Google...) .................... log de aviso, e a inscricao fica.
class Notification::FcmSender
  # Codigos que dizem que ESTE token nao serve mais.
  DEAD_TOKEN_CODES = %w[UNREGISTERED SENDER_ID_MISMATCH].freeze
  APNS_AUTH_CODES = %w[THIRD_PARTY_AUTH_ERROR].freeze

  Result = Struct.new(:status, :code, :message, keyword_init: true) do
    # Sem `status_code` (respostas antigas/dobradas) e sem erro, vale como entregue.
    def success?
      code.nil? && (status.to_i.zero? || status.to_i.between?(200, 299))
    end
  end

  # `description` entra nos logs ("fulano@x.com com o titulo ..."); `account` e' para o
  # rastreador de excecoes.
  pattr_initialize [:subscription!, :options!, :account, :description]

  def deliver
    return if project_id.blank? || credentials.blank?

    result = parse(client.send_v1(options))
    handle(result)
    result
  rescue StandardError => e
    # Rede, token do Google... uma inscricao com problema nao pode derrubar as
    # outras do mesmo aviso.
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    nil
  end

  private

  def project_id
    GlobalConfigService.load('FIREBASE_PROJECT_ID', nil)
  end

  def credentials
    GlobalConfigService.load('FIREBASE_CREDENTIALS', nil)
  end

  def client
    Notification::FcmService.new(project_id, credentials).fcm_client
  end

  def parse(response)
    body = response[:body]
    body = parse_json(body) if body.is_a?(String)
    error = body.is_a?(Hash) ? body['error'].to_h : {}

    Result.new(status: response[:status_code], code: error_code(error), message: error['message'])
  end

  def parse_json(text)
    text.present? ? JSON.parse(text) : {}
  rescue JSON::ParserError
    {}
  end

  # O codigo preciso vem em `details[].errorCode`; `status` e' o generico (NOT_FOUND...).
  def error_code(error)
    Array(error['details']).filter_map { |detail| detail['errorCode'] if detail.is_a?(Hash) }.first || error['status']
  end

  def handle(result)
    if result.success?
      Rails.logger.info("[FCM] push enviado #{identity} #{description}".strip)
    elsif dead_token?(result)
      Rails.logger.info("[FCM] token invalido removido (#{result.code}) #{identity}")
      subscription.destroy!
    elsif APNS_AUTH_CODES.include?(result.code)
      report("o Google nao conseguiu autenticar no APNs/Web Push - confira a chave de APNs no Firebase (#{result.code}) #{identity}")
    else
      Rails.logger.warn("[FCM] falha no envio (HTTP #{result.status} #{result.code}: #{result.message}) #{identity}")
    end
  end

  def dead_token?(result)
    DEAD_TOKEN_CODES.include?(result.code) ||
      (result.code == 'INVALID_ARGUMENT' && result.message.to_s.match?(/registration token/i))
  end

  def report(message)
    Rails.logger.error("[FCM] #{message}")
    ChatwootExceptionTracker.new(StandardError.new("[FCM] #{message}"), account: account).capture_exception
  end

  # Quem e' (e de que plataforma, quando o app informa): e' o que permite separar iOS de
  # Android nos logs.
  def identity
    platform = subscription.subscription_attributes.to_h['platform'].presence || 'plataforma desconhecida'
    "[#{subscription.class.name}##{subscription.id}, #{platform}]"
  end
end
