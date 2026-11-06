require 'rails_helper'

# Aviso/encerramento por inatividade nao pode sair em duplicidade.
#
# No Portal do Cliente agem DOIS servicos, em jobs paralelos: o da Fila
# (Queues::InactivityService) e o da caixa (Inboxes::InactivityService). Se os
# dois cuidassem da mesma conversa, o cliente recebia o aviso duas vezes. Aqui
# vale: a Fila, quando tem regras, manda; e cada servico trava a conversa e
# reconfere o estado antes de avisar/encerrar.
describe 'Inatividade: sem mensagem em duplicidade' do
  let!(:account) { create(:account) }
  let!(:team) { create(:team, account: account) }
  let!(:agente) { create(:user, account: account) }
  let!(:contato) { create(:contact, account: account) }
  let!(:portal_inbox) { Inboxes::EnsureClientPortalInboxService.new(account: account).perform }

  let(:regras_da_caixa) do
    { 'nudge_after' => 10, 'inactivity_message' => 'Ainda está aí? (caixa)',
      'close_after' => 30, 'resolve_message' => 'Encerrado por inatividade (caixa)' }
  end
  let(:fila_com_regras) do
    ServiceQueue.create!(account: account, team: team, name: 'Suporte', distribution_strategy: 'manual',
                         inactivity_nudge_after: 10, inactivity_nudge_message: 'Ainda está aí? (fila)',
                         inactivity_close_after: 30, inactivity_close_message: 'Encerrado por inatividade (fila)')
  end
  let(:fila_sem_regras) do
    ServiceQueue.create!(account: account, team: team, name: 'Sem regras', distribution_strategy: 'manual')
  end

  before { portal_inbox.update!(inactivity_config: regras_da_caixa) }

  # Conversa esperando o cliente: a ultima mensagem foi da equipe, ha 1 hora.
  def conversa_esperando_cliente(fila)
    conversa = create(:conversation, account: account, inbox: portal_inbox, contact: contato, queue: fila)
    create(:message, account: account, inbox: portal_inbox, conversation: conversa,
                     message_type: :outgoing, sender: agente, content: 'Pode me enviar o print?', created_at: 1.hour.ago)
    conversa.update_columns(last_activity_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    conversa
  end

  def avisos(conversa, tipo)
    conversa.messages.where("content_attributes ->> 'inactivity_notice' = ?", tipo)
  end

  def rodar_caixa
    Inboxes::InactivityService.new(inbox: portal_inbox).perform
  end

  def rodar_fila(fila)
    Queues::InactivityService.new(queue: fila).perform
  end

  context 'quando a Fila da conversa tem regras de inatividade' do
    it 'manda um unico aviso, com o texto da Fila, nas duas ordens de execucao' do
      conversa = conversa_esperando_cliente(fila_com_regras)

      rodar_caixa
      rodar_fila(fila_com_regras)
      rodar_caixa

      expect(avisos(conversa, 'nudge').pluck(:content)).to eq(['Ainda está aí? (fila)'])
    end

    it 'encerra uma unica vez, com a mensagem da Fila' do
      conversa = conversa_esperando_cliente(fila_com_regras)
      conversa.update!(additional_attributes: { 'inactivity_nudged_at' => 40.minutes.ago.iso8601 })

      rodar_caixa
      rodar_fila(fila_com_regras)
      rodar_caixa

      expect(conversa.reload).to be_resolved
      expect(avisos(conversa, 'close').pluck(:content)).to eq(['Encerrado por inatividade (fila)'])
    end
  end

  context 'quando a conversa nao tem Fila com regras' do
    it 'a caixa avisa uma unica vez, mesmo rodando varias vezes' do
      conversa = conversa_esperando_cliente(fila_sem_regras)

      3.times { rodar_caixa }
      rodar_fila(fila_com_regras)

      expect(avisos(conversa, 'nudge').pluck(:content)).to eq(['Ainda está aí? (caixa)'])
    end
  end

  # O servico decide com a conversa lida antes do lock; entre a leitura e o aviso
  # o cliente pode ter respondido ou outro job ja pode ter encerrado.
  context 'quando a conversa mudou entre a leitura e o aviso' do
    let(:servico_da_caixa) { Inboxes::InactivityService.new(inbox: portal_inbox) }
    let(:servico_da_fila) { Queues::InactivityService.new(queue: fila_com_regras) }

    it 'nao avisa se o cliente respondeu nesse intervalo (caixa)' do
      conversa = conversa_esperando_cliente(nil)
      desatualizada = Conversation.find(conversa.id)
      create(:message, account: account, inbox: portal_inbox, conversation: conversa,
                       message_type: :incoming, sender: contato, content: 'Já enviei!')

      servico_da_caixa.send(:nudge, desatualizada)

      expect(avisos(conversa, 'nudge')).to be_empty
    end

    it 'nao avisa se o cliente respondeu nesse intervalo (Fila)' do
      conversa = conversa_esperando_cliente(fila_com_regras)
      desatualizada = Conversation.find(conversa.id)
      create(:message, account: account, inbox: portal_inbox, conversation: conversa,
                       message_type: :incoming, sender: contato, content: 'Já enviei!')

      servico_da_fila.send(:nudge, desatualizada)

      expect(avisos(conversa, 'nudge')).to be_empty
    end

    it 'nao encerra de novo uma conversa que outro job ja encerrou (caixa)' do
      conversa = conversa_esperando_cliente(nil)
      desatualizada = Conversation.find(conversa.id)
      Conversation.find(conversa.id).update!(status: :resolved)

      servico_da_caixa.send(:close, desatualizada, 1.hour.ago)

      expect(avisos(conversa, 'close')).to be_empty
    end

    it 'nao encerra de novo uma conversa que outro job ja encerrou (Fila)' do
      conversa = conversa_esperando_cliente(fila_com_regras)
      desatualizada = Conversation.find(conversa.id)
      Conversation.find(conversa.id).update!(status: :resolved)

      servico_da_fila.send(:close, desatualizada, 1.hour.ago)

      expect(avisos(conversa, 'close')).to be_empty
    end
  end
end
