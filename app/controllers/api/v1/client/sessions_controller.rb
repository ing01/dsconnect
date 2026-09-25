# Entrar e sair da Area do Cliente.
#
# Fica fora da base autenticada por motivo obvio - e aqui que a sessao nasce -
# mas valida a senha com o MESMO mecanismo do usuario interno: `valid_password?`
# do Devise, sobre o hash bcrypt gravado no proprio contato.
class Api::V1::Client::SessionsController < ApplicationController
  include RequestExceptionHandler
  include ClientAreaLocale

  respond_to :json
  around_action :handle_with_exception

  def create
    contato = find_contact

    # Uma unica mensagem para credencial errada, contato inexistente e acesso
    # desligado: dizer qual dos tres e contar a quem tentou o que ele acertou.
    return render_invalid unless contato&.client_access? && contato.valid_password?(params[:password])

    contato.register_client_sign_in!
    @contact = contato
    @token = contato.client_access_token.token
    render 'api/v1/client/sessions/create', status: :ok
  end

  def destroy
    token = request.headers['api_access_token'] || request.headers['HTTP_API_ACCESS_TOKEN']
    dono = AccessToken.find_by(token: token)&.owner if token.present?
    dono.revoke_client_sessions! if dono.is_a?(Contact)
    head :ok
  end

  private

  # O e-mail do contato e o login, como pedido. A busca e case-insensitive
  # porque o indice unico de e-mail do contato tambem e. Memoizada: o idioma da
  # resposta tambem sai daqui, e a recusa nao deve custar duas consultas.
  def find_contact
    return @find_contact if defined?(@find_contact)
    return @find_contact = nil if params[:email].blank?

    @find_contact = Contact.with_client_access.find_by('lower(contacts.email) = ?', params[:email].to_s.strip.downcase)
  end

  def render_invalid
    render json: { error: I18n.t('client_area.invalid_credentials') }, status: :unauthorized
  end
end
