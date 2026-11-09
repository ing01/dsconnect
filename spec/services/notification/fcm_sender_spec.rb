require 'rails_helper'

# O defeito: o envio olhava `results` (formato legado do FCM) e a API v1 responde erro em
# `error` - entao TODA falha de entrega passava por sucesso e sumia sem log, e o token de um
# app desinstalado nunca era removido. O iPhone sem chave de APNs no Firebase era um desses
# erros invisiveis (`THIRD_PARTY_AUTH_ERROR`).
RSpec.describe Notification::FcmSender do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:subscription) do
    create(:notification_subscription, :fcm, user: user, identifier: 'device-1',
                                             subscription_attributes: { 'device_id' => 'device-1', 'push_token' => 'tok', 'platform' => 'ios' })
  end

  let(:fcm) { instance_double(FCM) }
  let(:tracker) { instance_double(ChatwootExceptionTracker, capture_exception: true) }
  let(:sender) { described_class.new(subscription: subscription, options: { token: 'tok' }, account: account, description: 'para alguem') }

  def error_response(status, error_status, code = nil, message = 'mensagem do Google')
    details = code ? [{ '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode' => code }] : []
    { status_code: status,
      body: { error: { code: status, message: message, status: error_status, details: details } }.to_json }
  end

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('FIREBASE_PROJECT_ID', nil).and_return('projeto')
    allow(GlobalConfigService).to receive(:load).with('FIREBASE_CREDENTIALS', nil).and_return('{}')
    allow(Notification::FcmService).to receive(:new).and_return(instance_double(Notification::FcmService, fcm_client: fcm))
    allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe 'quando entrega' do
    it 'registra o envio e mantem a inscricao' do
      allow(fcm).to receive(:send_v1).and_return({ status_code: 200, body: { name: 'projects/projeto/messages/1' }.to_json })

      expect(sender.deliver).to be_success
      expect(subscription.reload).to be_present
      expect(Rails.logger).to have_received(:info).with(/push enviado.*ios/)
    end

    # As respostas dobradas dos outros specs nao trazem `status_code`.
    it 'trata uma resposta sem status e sem erro como entregue' do
      allow(fcm).to receive(:send_v1).and_return({ body: { results: [] }.to_json })

      expect(sender.deliver).to be_success
      expect(subscription.reload).to be_present
    end
  end

  describe 'token morto' do
    it 'remove a inscricao quando o token nao esta mais registrado (app desinstalado)' do
      allow(fcm).to receive(:send_v1).and_return(error_response(404, 'NOT_FOUND', 'UNREGISTERED'))

      sender.deliver

      expect(NotificationSubscription.exists?(subscription.id)).to be(false)
      expect(Rails.logger).to have_received(:info).with(/token invalido removido \(UNREGISTERED\)/)
    end

    it 'remove quando o token e de outro projeto do Firebase' do
      allow(fcm).to receive(:send_v1).and_return(error_response(403, 'PERMISSION_DENIED', 'SENDER_ID_MISMATCH'))

      sender.deliver

      expect(NotificationSubscription.exists?(subscription.id)).to be(false)
    end

    it 'remove quando o Google diz que o token nao e valido' do
      allow(fcm).to receive(:send_v1)
        .and_return(error_response(400, 'INVALID_ARGUMENT', nil, 'The registration token is not a valid FCM registration token'))

      sender.deliver

      expect(NotificationSubscription.exists?(subscription.id)).to be(false)
    end

    it 'funciona tambem com a inscricao de um cliente' do
      contato = create(:contact, account: account)
      cliente = ClientPushSubscription.create!(account: account, contact: contato, subscription_type: :fcm,
                                               subscription_attributes: { 'device_id' => 'd', 'push_token' => 't' })
      allow(fcm).to receive(:send_v1).and_return(error_response(404, 'NOT_FOUND', 'UNREGISTERED'))

      described_class.new(subscription: cliente, options: {}, account: account).deliver

      expect(ClientPushSubscription.exists?(cliente.id)).to be(false)
    end
  end

  # O token e' bom; quem esta errado e' a chave de APNs no Firebase. Apagar o token so'
  # esconderia o problema e faria o cliente ter de registrar de novo depois de corrigido.
  describe 'APNs sem chave no Firebase' do
    before { allow(fcm).to receive(:send_v1).and_return(error_response(401, 'UNAUTHENTICATED', 'THIRD_PARTY_AUTH_ERROR')) }

    it 'mantem a inscricao e grita no log' do
      sender.deliver

      expect(subscription.reload).to be_present
      expect(Rails.logger).to have_received(:error).with(/chave de APNs no Firebase.*THIRD_PARTY_AUTH_ERROR.*ios/)
    end

    it 'avisa o rastreador de excecoes' do
      sender.deliver

      expect(ChatwootExceptionTracker).to have_received(:new).with(an_instance_of(StandardError), account: account)
      expect(tracker).to have_received(:capture_exception)
    end
  end

  describe 'outras falhas' do
    it 'mantem a inscricao numa instabilidade do Google, so avisando' do
      allow(fcm).to receive(:send_v1).and_return(error_response(503, 'UNAVAILABLE'))

      sender.deliver

      expect(subscription.reload).to be_present
      expect(Rails.logger).to have_received(:warn).with(/HTTP 503/)
    end

    # Um INVALID_ARGUMENT que nao fala do token (payload mal formado) nao pode apagar
    # a inscricao de ninguem.
    it 'nao apaga a inscricao por um argumento invalido que nao e do token' do
      allow(fcm).to receive(:send_v1).and_return(error_response(400, 'INVALID_ARGUMENT', nil, 'Invalid value at message.apns'))

      sender.deliver

      expect(subscription.reload).to be_present
    end

    it 'engole uma excecao de rede sem derrubar quem chama, e avisa o rastreador' do
      allow(fcm).to receive(:send_v1).and_raise(Faraday::ConnectionFailed, 'sem rede')

      expect(sender.deliver).to be_nil
      expect(tracker).to have_received(:capture_exception)
      expect(subscription.reload).to be_present
    end

    it 'nao chama o Google sem credenciais do Firebase' do
      allow(GlobalConfigService).to receive(:load).with('FIREBASE_CREDENTIALS', nil).and_return(nil)
      allow(fcm).to receive(:send_v1)

      expect(sender.deliver).to be_nil
      expect(fcm).not_to have_received(:send_v1)
    end
  end
end
