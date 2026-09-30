# A inscricao de push do navegador do cliente - mesmo mecanismo VAPID que o
# painel interno ja usa (`NotificationSubscriptions`), so que dono e' o
# Contato logado, e nao um usuario.
#
# Sem `destroy`: uma inscricao invalida (navegador desinstalado, permissao
# revogada) se auto-limpa quando o envio falha
# (`Client::ChatPushNotificationService`), sem precisar de uma rota para isso.
class Api::V1::Client::PushSubscriptionsController < Api::V1::Client::BaseController
  def create
    endpoint = permitted_params.dig(:subscription_attributes, :endpoint)
    return head :unprocessable_entity if endpoint.blank?

    Current.account.client_push_subscriptions
           .where("subscription_attributes ->> 'endpoint' = ?", endpoint)
           .first_or_create!(contact: current_contact, subscription_attributes: permitted_params[:subscription_attributes])

    head :ok
  end

  private

  def permitted_params
    params.permit(subscription_attributes: [:endpoint, :p256dh, :auth])
  end
end
