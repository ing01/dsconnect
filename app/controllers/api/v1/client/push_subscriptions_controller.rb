# A inscricao de push do cliente - mesmo mecanismo que o painel interno ja
# usa (`NotificationSubscriptions`), so que dono e' o Contato logado, e nao
# um usuario. Dois tipos: `browser_push` (VAPID, o Portal no navegador) e
# `fcm` (o app mobile do cliente final).
#
# `destroy` e' so' do app mobile: ao SAIR da conta o aparelho se desinscreve e
# para de receber os avisos desse contato. Uma inscricao invalida (navegador ou
# app desinstalado, permissao revogada) continua se auto-limpando quando o
# envio falha (`Client::PushNotificationDeliverable`).
class Api::V1::Client::PushSubscriptionsController < Api::V1::Client::BaseController
  def create
    permitted_params[:subscription_type] == 'fcm' ? create_fcm_subscription : create_browser_subscription
  end

  # Escopo no contato logado: um aparelho nunca desinscreve o de outra pessoa.
  def destroy
    current_contact.client_push_subscriptions.fcm
                   .where("subscription_attributes ->> 'device_id' = ?", params[:device_id])
                   .destroy_all

    head :ok
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
