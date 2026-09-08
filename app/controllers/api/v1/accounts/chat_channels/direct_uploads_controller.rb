# Cria o blob para um arquivo que o navegador envia direto ao storage.
#
# Existe para que o upload nao passe pela aplicacao: com object storage o
# navegador fala direto com o bucket, e o Rails so registra o blob e recebe
# depois o signed id junto da mensagem.
#
# A sala e procurada dentro das salas de quem esta logado - mesma regra do
# ChatMessagesController -, entao nao ha como abrir espaco de upload num lugar
# de que a pessoa nao participa.
class Api::V1::Accounts::ChatChannels::DirectUploadsController < ActiveStorage::DirectUploadsController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include EnsureCurrentAccountHelper

  # O ActiveStorage::DirectUploadsController nao herda do ApplicationController,
  # onde a aplicacao ja dispensa o CSRF: aqui a autenticacao e por header de
  # token, e nao por cookie de sessao, entao o token de formulario nao se aplica.
  skip_before_action :verify_authenticity_token

  around_action :handle_with_exception
  before_action :authenticate_user!
  before_action :current_account
  before_action :chat_channel

  def create
    # Diz o que houve, em vez do 204 mudo: sem isso o cliente recebe uma
    # resposta vazia com cara de sucesso e so quebra no passo seguinte.
    return head :not_found if @chat_channel.nil? || @current_account.nil?

    super
  end

  private

  def chat_channel
    # `current_user` e nao `Current.user`: este controller nao passa pelo
    # ApplicationController, entao o Current so recebe a conta.
    @chat_channel ||= ChatChannel.for_user(current_user).find_by(
      id: params[:chat_channel_id], account_id: @current_account.id
    )
  end
end
