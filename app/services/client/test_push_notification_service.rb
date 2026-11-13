# O aviso de TESTE do botao "Testar" da Area do Cliente: sai pelo mesmo caminho
# (`Client::PushNotificationDeliverable`) e para os mesmos aparelhos das
# notificacoes reais - se este chega, as reais chegam.
class Client::TestPushNotificationService
  include Client::PushNotificationDeliverable
  pattr_initialize [:contact!, :push_account!]

  def perform
    deliver_push!
  end

  private

  def push_message
    {
      title: I18n.t('client_area.push_test.title'),
      body: I18n.t('client_area.push_test.body'),
      tag: 'client_push_test',
      url: '/app/client/tutorials',
      actions: [{ action: 'open', title: I18n.t('client_area.push_test.action_open') }]
    }
  end
end
