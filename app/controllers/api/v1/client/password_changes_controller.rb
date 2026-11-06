# A troca da senha padrao no primeiro acesso.
#
# Roda COM sessao (diferente da redefinicao por e-mail, em PasswordsController):
# quem chega aqui acabou de entrar com a senha padrao e a trava de
# `require_password_change_done!` so deixa passar esta acao. Exige a senha atual
# de novo, para uma sessao esquecida aberta nao conseguir fixar uma senha nova.
class Api::V1::Client::PasswordChangesController < Api::V1::Client::BaseController
  skip_before_action :require_password_change_done!

  def update
    resultado = current_contact.change_client_password(
      current_password: params[:current_password],
      password: params[:password],
      confirmation: params[:password_confirmation]
    )

    return render json: { message: I18n.t('client_area.password_change.updated') } if resultado == :ok

    render json: { error: I18n.t("client_area.password_change.errors.#{resultado}") }, status: :unprocessable_entity
  end
end
