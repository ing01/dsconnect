# Exige LOGIN para baixar anexo.
#
# O ActiveStorage entrega arquivo por link assinado: quem tem o link baixa, sem
# sessao nenhuma - e o link "permanente" (`rails_blob_url`, o `file_url` que a API
# devolve) nunca expira. Qualquer pessoa que ja tenha visto o endereco, num log,
# num e-mail encaminhado ou numa conversa colada em outro lugar, baixa o arquivo
# de um cliente de aba anonima. Aqui o download passa a pedir a mesma credencial
# que o resto do sistema.
#
# Quem pode baixar (qualquer uma das tres):
#   - Agente: os 3 cabecalhos do devise_token_auth (access-token/client/uid), ou o
#     cookie `cw_d_session_info` que o painel ja grava no navegador. E' o cookie
#     que faz `<img src>` e abrir o link numa aba nova funcionarem sem JavaScript.
#   - Cliente: o cabecalho `api_access_token` (app) ou o cookie
#     `cw_client_session` (Portal web), com o acesso ao Portal ainda ligado.
#   - Integracao: a chave `X-Ticket-Api-Key` da API de Integracao de Tickets, que
#     entrega `file_url` a um sistema externo.
#
# Fica de fora so' o que aparece em pagina PUBLICA: o logo do Portal (Central de
# Ajuda). `ACTIVE_STORAGE_REQUIRE_LOGIN=false` desliga tudo isto, para o caso de
# alguma integracao que nao se previu deixar de baixar arquivo - e' uma valvula
# de emergencia, nao uma configuracao.
#
# Vale para o primeiro salto (redirect/proxy do blob e da miniatura) E para o link
# de disco que ele devolve: um `blob.url` montado direto no codigo tambem passa
# por aqui, e deixa de ser um atalho.
module ActiveStorageAttachmentAccess
  extend ActiveSupport::Concern

  AGENT_COOKIE = 'cw_d_session_info'.freeze
  CLIENT_COOKIE = 'cw_client_session'.freeze
  AGENT_HEADERS = %w[access-token client uid].freeze

  # Registros cujo arquivo e' exibido em pagina publica.
  PUBLIC_RECORD_TYPES = %w[Portal].freeze

  included do
    # `prepend`: a checagem vem ANTES de `set_blob`/`set_representation`, que
    # processam a imagem - um pedido anonimo nao deve custar CPU nenhuma.
    # So' `show`: o `update` do disco e' o upload direto, que tem as guardas dele.
    prepend_before_action :require_attachment_access, if: -> { action_name == 'show' }
  end

  private

  def require_attachment_access
    return unless login_required?
    return if public_blob?
    return if agent_session? || token_session? || integration_key?

    Rails.logger.info "[AttachmentAccess] negado: #{request.path} (#{request.remote_ip})"
    deny_attachment_access
  end

  def login_required?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ACTIVE_STORAGE_REQUIRE_LOGIN', 'true')) != false
  end

  # Navegador abrindo o link: leva ao login. `<img>`, `fetch` e app: 401 seco, que
  # e' o que eles sabem tratar.
  def deny_attachment_access
    if request.headers['Accept'].to_s.include?('text/html')
      redirect_to '/app/login'
    else
      head :unauthorized
    end
  end

  # ---- o que e' publico ---------------------------------------------------

  def public_blob?
    blob = requested_blob
    return false if blob.blank?

    types = blob.attachments.pluck(:record_type)
    types.any? && types.all? { |type| PUBLIC_RECORD_TYPES.include?(type) }
  rescue StandardError
    false
  end

  # O blob que o link pede. Os controllers do ActiveStorage trazem o id assinado
  # (`signed_blob_id`/`signed_id`) no redirect, e a chave assinada (`encoded_key`)
  # no link de disco. Qualquer falha aqui significa "nao e' publico".
  def requested_blob
    @requested_blob ||=
      if params[:encoded_key].present?
        payload = ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
        key = payload.to_h.with_indifferent_access[:key]
        ActiveStorage::Blob.find_by(key: key) if key.present?
      else
        signed = params[:signed_blob_id] || params[:signed_id]
        ActiveStorage::Blob.find_signed(signed) if signed.present?
      end
  end

  # ---- quem esta logado ---------------------------------------------------

  def agent_session?
    credentials = agent_credentials
    return false if credentials.values.any?(&:blank?)

    user = User.find_by(uid: credentials['uid'])
    user.present? && user.valid_token?(credentials['access-token'], credentials['client'])
  end

  def agent_credentials
    from_headers = AGENT_HEADERS.index_with { |name| request.headers[name] }
    return from_headers if from_headers.values.all?(&:present?)

    cookie = parsed_cookie(AGENT_COOKIE)
    AGENT_HEADERS.index_with { |name| cookie[name].to_s }
  end

  # Token de acesso: o do contato (Portal/app do cliente) ou o de um usuario. Para
  # o contato, vale so' enquanto o acesso estiver ligado - a mesma regra de
  # Api::V1::Client::BaseController, aplicada a cada requisicao.
  def token_session?
    token = request.headers['api_access_token'].presence ||
            request.headers['HTTP_API_ACCESS_TOKEN'].presence ||
            parsed_cookie(CLIENT_COOKIE)['token'].presence
    return false if token.blank?

    owner = AccessToken.find_by(token: token.to_s)&.owner
    owner.is_a?(User) || (owner.is_a?(Contact) && owner.client_access?)
  end

  def integration_key?
    key = request.headers['X-Ticket-Api-Key']
    key.present? && TicketApiKey.exists?(token: key)
  end

  def parsed_cookie(name)
    raw = cookies[name]
    parsed = raw.present? ? JSON.parse(raw) : {}
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end
end
