class SwaggerController < ApplicationController
  # Fora de development/test, a doc so abre com usuario/senha (pensado para o
  # time externo que consome a API de Integracao de Tickets acessar o
  # /swagger em producao). `before_action` em vez de `http_basic_authenticate_with`
  # de proposito: aquele valida o `name:`/`password:` na hora de CARREGAR a
  # classe, e explode se a ENV nao estiver setada - aqui a checagem so roda
  # por requisicao, e sem ENV configurada ela simplesmente nunca autentica
  # (fechada por padrao, nao aberta por padrao).
  before_action :require_docs_credentials, unless: -> { Rails.env.development? || Rails.env.test? }

  def respond
    swagger_root = Rails.root.join('swagger')
    file_path = swagger_root.join(derived_path).cleanpath

    return head :not_found unless file_path.to_s.start_with?("#{swagger_root}/") && file_path.file?

    render inline: file_path.read
  end

  private

  def require_docs_credentials
    authenticate_or_request_with_http_basic do |name, password|
      ActiveSupport::SecurityUtils.secure_compare(name.to_s, ENV.fetch('SWAGGER_DOCS_USER', '')) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, ENV.fetch('SWAGGER_DOCS_PASSWORD', ''))
    end
  end

  def derived_path
    params[:path] ||= 'index.html'
    path = Rack::Utils.clean_path_info(params[:path]).delete_prefix('/')
    path << ".#{Rack::Utils.clean_path_info(params[:format]).delete_prefix('/')}" unless path.ends_with?(params[:format].to_s)
    path
  end
end
