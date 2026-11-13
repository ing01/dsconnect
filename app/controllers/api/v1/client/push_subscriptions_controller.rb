# A inscricao de push do cliente - mesmo mecanismo que o painel interno ja
# usa (`NotificationSubscriptions`), so que dono e' o Contato logado, e nao
# um usuario. Dois tipos: `browser_push` (VAPID, o Portal no navegador) e
# `fcm` (o app mobile do cliente final).
#
# `destroy` cancela a inscricao de UM aparelho: o app mobile (`device_id`), ao SAIR da
# conta, e o navegador (`endpoint`), quando a pessoa desliga as notificacoes pelo
# botao do Portal. Uma inscricao invalida (navegador ou
# app desinstalado, permissao revogada) continua se auto-limpando quando o
# envio falha (`Client::PushNotificationDeliverable`).
class Api::V1::Client::PushSubscriptionsController < Api::V1::Client::BaseController
  def create
    permitted_params[:subscription_type] == 'fcm' ? create_fcm_subscription : create_browser_subscription
  end

  # Escopo no contato logado: um aparelho nunca desinscreve o de outra pessoa.
  def destroy
    subscriptions = current_contact.client_push_subscriptions
    if params[:endpoint].present?
      subscriptions.browser_push.where("subscription_attributes ->> 'endpoint' = ?", params[:endpoint]).destroy_all
    else
      subscriptions.fcm.where("subscription_attributes ->> 'device_id' = ?", params[:device_id]).destroy_all
    end

    head :ok
  end

  # O botao "Testar" da Area do Cliente: o aviso sai pelo MESMO caminho das notificacoes
  # reais, entao se ele chega, as reais chegam. `devices: 0` quer dizer que nada esta
  # inscrito (a tela se reinscreve e avisa).
  def test_notification
    devices = current_contact.client_push_subscriptions.count
    Client::TestPushNotificationService.new(contact: current_contact, push_account: Current.account).perform if devices.positive?

    render json: { devices: devices }
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
    # `platform` (ios/android) so' serve para os logs de envio: sem ele nao ha como
    # saber, num erro de entrega, de qual sistema era o aparelho.
    params.permit(:subscription_type, subscription_attributes: [:endpoint, :p256dh, :auth, :device_id, :push_token, :platform])
  end
end
