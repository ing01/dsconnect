# A base de TODA a Area do Cliente.
#
# Um namespace proprio, e nao um `if cliente?` espalhado pelos controllers dos
# agentes: aqui quem esta autenticado e um CONTATO, nunca um usuario interno, e
# misturar os dois no mesmo controller e como um acesso indevido nasce.
#
# Nao herda de Api::V1::Accounts::BaseController de proposito - aquele exige
# `current_user` e um `account_user`, que o contato nao tem e nao deve ter.
class Api::V1::Client::BaseController < ApplicationController
  include RequestExceptionHandler
  include ClientAreaLocale

  respond_to :json

  before_action :authenticate_client!
  # Quem ainda esta com a senha padrao so pode trocar a senha (ou sair): sem esta
  # trava, a tela de troca seria enfeite e a senha padrao abriria tudo.
  before_action :require_password_change_done!
  around_action :handle_with_exception

  private

  # A sessao do cliente e um AccessToken - o mesmo modelo que o resto do sistema
  # ja usa - com o contato como dono. Sem tabela de sessao nova.
  def authenticate_client!
    Current.reset
    contato = contact_from_token

    # A checagem e a cada requisicao, e nao so no login: desligar o acesso
    # precisa derrubar quem ja estava dentro.
    return render_client_unauthorized unless contato&.client_access?
    # Senha padrao vencida derruba ate a sessao aberta: so o "esqueci minha senha" resolve.
    return render_client_unauthorized if contato.client_default_password_expired?

    @current_contact = contato
    Current.contact = contato
    Current.account = contato.account
  end

  # Memoizado porque a autenticacao e o `Current` perguntam a mesma coisa.
  def contact_from_token
    return @contact_from_token if defined?(@contact_from_token)

    token = request.headers['api_access_token'] || request.headers['HTTP_API_ACCESS_TOKEN']
    dono = AccessToken.find_by(token: token)&.owner if token.present?
    @contact_from_token = dono.is_a?(Contact) ? dono : nil
  end

  attr_reader :current_contact

  def web_client?
    request.headers['X-Client-Platform'].to_s == 'web'
  end

  # O codigo vai junto para a tela mandar a pessoa ao formulario de troca.
  #
  # So vale para a WEB: o app do celular entra normalmente com a senha padrao,
  # sem troca. A web se identifica pelo cabecalho que o cliente HTTP dela manda
  # (api/clientArea.js); quem nao manda e' tratado como app.
  def require_password_change_done!
    return unless current_contact&.password_change_required? && web_client?

    render json: { error: I18n.t('client_area.password_change.required'), code: 'password_change_required' },
           status: :forbidden
  end

  # O chat com a equipe e' vetado a contato bloqueado. O codigo vai junto para
  # as telas (portal e app) mostrarem o aviso em vez de uma mensagem generica.
  def ensure_chat_allowed
    return if current_contact.client_chat_allowed?

    render json: { error: I18n.t('client_area.chat_blocked'), code: 'chat_blocked' }, status: :forbidden
  end

  def render_client_unauthorized
    render json: { error: I18n.t('client_area.unauthorized') }, status: :unauthorized
  end

  # A fronteira de tudo que a Area do Cliente enxerga. Toda consulta de ticket
  # parte daqui - nenhum controller monta a sua propria.
  def visible_tickets
    current_contact.visible_tickets
  end

  # O ticket pedido, SE ele estiver dentro da fronteira. Trocar o id na URL cai
  # aqui e vira 404, nao um ticket de outra empresa.
  def fetch_ticket
    @ticket = visible_tickets.find(params[:id])
  end
end
