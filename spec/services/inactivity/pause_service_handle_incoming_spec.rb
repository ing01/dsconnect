require 'rails_helper'

# Portal do Cliente: a conversa foi pausada por inatividade (some da fila e do
# atendente) e o cliente volta a escrever.
#
# A mensagem de pausa diz "Responda SIM (ou envie qualquer mensagem) para retomar, ou
# NAO para encerrar". Qualquer texto do cliente tira a conversa de "Pausadas": ela volta
# para o atendente anterior, se estiver disponivel, ou para a fila. So o "nao" encerra.
#
# O defeito que isto cobre: com a retomada "com um clique" desligada, um texto que nao
# fosse "sim"/"nao" deixava a conversa pausada, em silencio - a mensagem real do cliente
# ficava escondida em Pausadas e ninguem a via.
describe Inactivity::PauseService, '.handle_incoming' do
  let!(:account) { create(:account) }
  let!(:agente) { create(:user, account: account) }
  let!(:contato) { create(:contact, account: account) }
  let!(:portal_inbox) { Inboxes::EnsureClientPortalInboxService.new(account: account).perform }
  let(:pause_config) { { 'pause_enabled' => true, 'pause_after' => 5, 'pause_window' => 120, 'respect_working_hours' => false } }

  def conversa_pausada
    portal_inbox.update!(inactivity_config: pause_config)
    conversa = create(:conversation, account: account, inbox: portal_inbox, contact: contato, assignee: agente)
    create(:message, account: account, inbox: portal_inbox, conversation: conversa,
                     message_type: :outgoing, sender: agente, content: 'Pode me enviar o print?', created_at: 1.hour.ago)
    conversa.update_columns(last_activity_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    Inboxes::InactivityService.new(inbox: portal_inbox).perform
    conversa.reload
  end

  # Como o Portal grava a mensagem do cliente (Api::V1::Client::ChatMessagesController).
  def cliente_escreve(conversa, texto)
    Messages::MessageBuilder.new(nil, conversa, { content: texto, message_type: 'incoming' }).perform
    conversa.reload
  end

  def avisos_de_retomada(conversa)
    conversa.messages.to_a.select { |m| m.content_attributes['inactivity_notice'] == 'resume' }
  end

  it 'a pausa tira a conversa do atendente e a deixa pausada' do
    conversa = conversa_pausada

    expect(conversa).to be_snoozed
    expect(conversa.assignee_id).to be_nil
    expect(conversa.additional_attributes['paused_at']).to be_present
  end

  context 'when the previous agent is not available' do
    it 'um texto livre reabre a conversa e a devolve para a fila' do
      conversa = cliente_escreve(conversa_pausada, 'vou tentar novamente')

      expect(conversa).to be_open
      expect(conversa.assignee_id).to be_nil
      expect(conversa.additional_attributes).not_to include('paused_at')
    end

    it 'avisa a cliente que ela foi para a fila, uma vez so' do
      conversa = cliente_escreve(conversa_pausada, 'para em sincronizar clientes')

      expect(avisos_de_retomada(conversa).size).to eq(1)
    end

    it 'o texto da cliente fica na conversa (nao se perde)' do
      conversa = cliente_escreve(conversa_pausada, 'vou tentar novamente')

      expect(conversa.messages.incoming.pluck(:content)).to include('vou tentar novamente')
    end
  end

  context 'when the previous agent is online and available' do
    before do
      create(:inbox_member, inbox: portal_inbox, user: agente)
      OnlineStatusTracker.update_presence(account.id, 'User', agente.id)
      OnlineStatusTracker.set_status(account.id, agente.id, 'online')
    end

    it 'qualquer texto devolve a conversa para ele' do
      conversa = cliente_escreve(conversa_pausada, 'oi, voltei')

      expect(conversa).to be_open
      expect(conversa.assignee_id).to eq(agente.id)
    end
  end

  context 'with the old one-click setting still saved as off' do
    let(:pause_config) { super().merge('resume_one_click' => false) }

    it 'um texto livre reabre a conversa do mesmo jeito' do
      conversa = cliente_escreve(conversa_pausada, 'vou tentar novamente')

      expect(conversa).to be_open
      expect(conversa.additional_attributes).not_to include('paused_at')
    end
  end

  context 'when the customer answers yes or no' do
    it '"sim" reabre a conversa' do
      expect(cliente_escreve(conversa_pausada, 'sim')).to be_open
    end

    it '"nao" encerra a conversa, como a mensagem de pausa oferece' do
      expect(cliente_escreve(conversa_pausada, 'nao')).to be_resolved
    end
  end

  context 'when the pause deadline has already passed' do
    it 'a conversa e encerrada, e a mensagem inicia um atendimento novo' do
      conversa = conversa_pausada
      conversa.update!(additional_attributes: conversa.additional_attributes.merge('pause_deadline' => 1.minute.ago.iso8601))

      conversa = cliente_escreve(conversa, 'oi')

      expect(conversa).to be_resolved.or be_open
      expect(conversa.additional_attributes).not_to include('paused_at')
    end
  end
end
