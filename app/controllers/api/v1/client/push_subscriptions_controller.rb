# A inscricao de push do cliente - mesmo mecanismo que o painel interno ja
# usa (`NotificationSubscriptions`), so que dono e' o Contato logado, e nao
# um usuario. Dois tipos: `browser_push` (VAPID, o Portal no navegador) e
# `fcm` (o app mobile do cliente final).
#
# Sem `destroy`: uma inscricao invalida (navegador desinstalado, app
# desinstalado, permissao revogada) se auto-limpa quando o envio falha
# (`Client::PushNotificationDeliverable`), sem precisar de uma rota para isso.
class Api::V1::Client::PushSubscriptionsController < Api::V1::Client::BaseController
  def create
    permitted_params[:subscription_type] == 'fcm' ? create_fcm_subscription : create_browser_subscription
  end

  private

  def create_browser_subscription
    endpoint = permitted_params.dig(:subscription_attributes, :endpoint)
    return head :unprocessable_entity if endpoint.blank?

    Current.account.client_push_subscriptions
           .where("subscription_attributes ->> 'endpoint' = ?", endpoint)
           .first_or_create!(contact: current_contact, subscription_type: :browser_push,
                              subscription_attributes: permitted_params[:subscription_attributes])

    head :ok
  end

  # Ao contrario do browser_push (o `endpoint` mal muda), o token FCM do
  # aparelho roda periodicamente por conta do sistema operacional - por isso
  # aqui ATUALIZA a inscricao existente (mesmo `device_id`) em vez de so'
  # criar se nao achar, senao o token velho ficava parado recebendo erro ate
  # a inscricao se autodestruir sozinha.
  def create_fcm_subscription
    device_id = permitted_params.dig(:subscription_attributes, :device_id)
    return head :unprocessable_entity if device_id.blank?

    subscription = Current.account.client_push_subscriptions.fcm
                           .where("subscription_attributes ->> 'device_id' = ?", device_id)
                           .first_or_initialize
    subscription.contact = current_contact
    subscription.subscription_attributes = permitted_params[:subscription_attributes]
    subscription.save!

    head :ok
  end

  def permitted_params
    params.permit(:subscription_type, subscription_attributes: [:endpoint, :p256dh, :auth, :device_id, :push_token])
  end
end
