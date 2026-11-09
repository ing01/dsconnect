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

    # `code` e' a regra que falhou (wrong_current, too_short, mismatch, same_as_current,
    # same_as_default, invalid): a tela usa para colocar a mensagem embaixo do CAMPO certo.
    # `error` continua sendo o texto pronto, para quem so' o mostra (o app).
    log_invalid_password(resultado) if resultado == :invalid
    render json: { error: I18n.t("client_area.password_change.errors.#{resultado}"), code: resultado },
           status: :unprocessable_entity
  end

  private

  # `:invalid` e' o contato que nao passou nas validacoes do PROPRIO cadastro (nao e'
  # regra de senha) - o cliente nao tem como saber, entao o motivo vai para o log.
  def log_invalid_password(resultado)
    Rails.logger.warn("[PasswordChange] contato #{current_contact.id} #{resultado}: #{current_contact.errors.full_messages.to_sentence}")
  end
end
