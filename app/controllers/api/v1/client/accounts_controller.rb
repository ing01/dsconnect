# Exclusao da conta do cliente.
#
# Nao faz hard-delete do Contact: o historico de chamados e conversas permanece
# para a equipe interna, mas sem PII - o contato e anonimizado e o acesso e
# bloqueado permanentemente.
class Api::V1::Client::AccountsController < Api::V1::Client::BaseController
  def destroy
    unless current_contact.valid_password?(params[:password].to_s)
      render json: { error: I18n.t('client_area.wrong_password') }, status: :unauthorized
      return
    end

    anonymize_contact(current_contact)
    head :ok
  end

  private

  def anonymize_contact(contact)
    contact.revoke_client_sessions!
    ts = Time.current.to_i
    contact.update_columns(
      name: 'Conta excluída',
      email: "excluido_#{contact.id}_#{ts}@excluido.invalid",
      phone_number: nil,
      client_access_enabled: false,
      encrypted_password: ''
    )
  end
end
