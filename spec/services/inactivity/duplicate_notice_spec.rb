require 'rails_helper'

# Aviso/encerramento/pausa por inatividade nao pode sair em duplicidade nem se repetir.
#
# Dois problemas reais que isto cobre:
#
# 1. O aviso era mandado a cada ciclo (5 min) e nunca chegava a pausa/encerramento.
#    `Message#content_attributes` e' gravado como TEXTO JSON, entao filtrar por
#    `content_attributes ->> 'inactivity_notice'` no SQL nunca achava nada: o aviso
#    virava a "ultima mensagem da equipe" e reiniciava o relogio. Agora a marca e'
#    lida em Ruby (Inactivity::NoticeTracking).
# 2. No Portal agem DOIS servicos, em jobs paralelos: o da Fila e o da caixa. Se os
#    dois cuidassem da mesma conversa, o cliente recebia o aviso duas vezes. Vale: a
#    Fila, quando tem regras, manda; e cada servico trava a conversa e reconfere o
#    estado antes de avisar/encerrar/pausar.
#
# As mensagens sao lidas SEMPRE em Ruby aqui tambem - e' o mesmo caminho do servico.
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

  # Le a marca em Ruby, como o servico (nao por SQL, que nao enxerga a coluna).
  def avisos(conversa, tipo)
    Message.where(conversation_id: conversa.id).to_a.select { |m| m.content_attributes['inactivity_notice'] == tipo }
  end

  def rodar_caixa
    Inboxes::InactivityService.new(inbox: portal_inbox).perform
  end

  def rodar_fila(fila)
    Queues::InactivityService.new(queue: fila).perform
  end

  context 'quando o aviso ja foi enviado' do
    it 'nao avisa de novo a cada ciclo, mesmo que o marcador da conversa se perca' do
      conversa = conversa_esperando_cliente(nil)

      rodar_caixa
      expect(avisos(conversa, 'nudge').size).to eq(1)

      conversa.update!(additional_attributes: {}) # marcador perdido: a propria mensagem de aviso basta
      travel(11.minutes) { 3.times { rodar_caixa } }

      expect(avisos(conversa, 'nudge').size).to eq(1)
    end

    it 'o aviso nao conta como mensagem da equipe: depois do prazo encerra, sem novo aviso' do
      conversa = conversa_esperando_cliente(nil)

      rodar_caixa
      travel(35.minutes) { 2.times { rodar_caixa } }

      expect(conversa.reload).to be_resolved
      expect(avisos(conversa, 'nudge').size).to eq(1)
      expect(avisos(conversa, 'close').map(&:content)).to eq(['Encerrado por inatividade (caixa)'])
    end
  end

  context 'com a pausa ligada na caixa' do
    before do
      portal_inbox.update!(inactivity_config: regras_da_caixa.merge(
        'pause_enabled' => true, 'pause_after' => 5, 'pause_window' => 120, 'respect_working_hours' => false
      ))
    end

    it 'avisa uma vez, pausa uma vez e nao repete nenhum dos dois' do
      conversa = conversa_esperando_cliente(nil)

      rodar_caixa
      rodar_caixa
      expect(avisos(conversa, 'nudge').size).to eq(1)
      expect(conversa.reload).to be_open

      travel(6.minutes) { 3.times { rodar_caixa } }

      expect(conversa.reload).to be_snoozed
      expect(avisos(conversa, 'nudge').size).to eq(1)
      expect(avisos(conversa, 'pause').size).to eq(1)
    end

    it 'depois da pausa ja usada, encerra pelo prazo da pausa mesmo sem "encerrar apos" configurado' do
      portal_inbox.update!(inactivity_config: { 'nudge_after' => 10, 'inactivity_message' => 'Ainda está aí?',
                                                'resolve_message' => 'Encerrado por inatividade',
                                                'pause_enabled' => true, 'pause_after' => 5, 'respect_working_hours' => false })
      conversa = conversa_esperando_cliente(nil)
      conversa.update!(additional_attributes: { 'pause_count' => 1 })

      rodar_caixa
      travel(6.minutes) { 2.times { rodar_caixa } }

      expect(conversa.reload).to be_resolved
      expect(avisos(conversa, 'pause')).to be_empty
      expect(avisos(conversa, 'close').size).to eq(1)
    end

    it 'sem aviso configurado, pausa direto uma unica vez' do
      portal_inbox.update!(inactivity_config: { 'pause_enabled' => true, 'pause_after' => 5, 'respect_working_hours' => false })
      conversa = conversa_esperando_cliente(nil)

      3.times { rodar_caixa }

      expect(conversa.reload).to be_snoozed
      expect(avisos(conversa, 'nudge')).to be_empty
      expect(avisos(conversa, 'pause').size).to eq(1)
    end
  end

  context 'quando a Fila da conversa tem regras de inatividade' do
    it 'manda um unico aviso, com o texto da Fila, nas duas ordens de execucao' do
      conversa = conversa_esperando_cliente(fila_com_regras)

      rodar_caixa
      rodar_fila(fila_com_regras)
      rodar_caixa

      expect(avisos(conversa, 'nudge').map(&:content)).to eq(['Ainda está aí? (fila)'])
    end

    it 'com a pausa ligada na Fila, avisa uma vez e pausa uma vez' do
      fila = fila_com_regras
      fila.update!(inactivity_pause_config: { 'pause_enabled' => true, 'pause_after' => 5, 'respect_working_hours' => false })
      conversa = conversa_esperando_cliente(fila)

      rodar_caixa
      rodar_fila(fila)
      travel(6.minutes) do
        3.times do
          rodar_fila(fila)
          rodar_caixa
        end
      end

      expect(conversa.reload).to be_snoozed
      expect(avisos(conversa, 'nudge').size).to eq(1)
      expect(avisos(conversa, 'pause').size).to eq(1)
    end

    # Antes a Fila ignorava a pausa ligada so na caixa e ENCERRAVA a conversa.
    it 'com a pausa ligada so na caixa, a Fila avisa e a conversa PAUSA em vez de encerrar' do
      portal_inbox.update!(inactivity_config: regras_da_caixa.merge(
        'pause_enabled' => true, 'pause_after' => 5, 'respect_working_hours' => false
      ))
      conversa = conversa_esperando_cliente(fila_com_regras)

      rodar_caixa
      rodar_fila(fila_com_regras)
      travel(6.minutes) do
        3.times do
          rodar_fila(fila_com_regras)
          rodar_caixa
        end
      end

      expect(conversa.reload).to be_snoozed
      expect(conversa.additional_attributes['pause_origin']).to eq('inbox')
      expect(avisos(conversa, 'nudge').map(&:content)).to eq(['Ainda está aí? (fila)'])
      expect(avisos(conversa, 'pause').size).to eq(1)
      expect(avisos(conversa, 'close')).to be_empty
    end

    it 'a pausa ligada na propria Fila vale mais que a da caixa' do
      portal_inbox.update!(inactivity_config: regras_da_caixa.merge('pause_enabled' => true, 'pause_after' => 5))
      fila = fila_com_regras
      fila.update!(inactivity_pause_config: { 'pause_enabled' => true, 'pause_after' => 5, 'respect_working_hours' => false })
      conversa = conversa_esperando_cliente(fila)

      rodar_fila(fila)
      travel(6.minutes) { rodar_fila(fila) }

      expect(conversa.reload).to be_snoozed
      expect(conversa.additional_attributes['pause_origin']).to eq('queue')
    end

    it 'sem pausa em lugar nenhum, a Fila encerra como sempre' do
      conversa = conversa_esperando_cliente(fila_com_regras)
      conversa.update!(additional_attributes: { 'inactivity_nudged_at' => 40.minutes.ago.iso8601 })

      rodar_fila(fila_com_regras)

      expect(conversa.reload).to be_resolved
      expect(avisos(conversa, 'pause')).to be_empty
    end

    it 'encerra uma unica vez, com a mensagem da Fila' do
      conversa = conversa_esperando_cliente(fila_com_regras)
      conversa.update!(additional_attributes: { 'inactivity_nudged_at' => 40.minutes.ago.iso8601 })

      rodar_caixa
      rodar_fila(fila_com_regras)
      rodar_caixa

      expect(conversa.reload).to be_resolved
      expect(avisos(conversa, 'close').map(&:content)).to eq(['Encerrado por inatividade (fila)'])
    end
  end

  context 'quando a conversa nao tem Fila com regras' do
    it 'a caixa avisa uma unica vez, mesmo rodando varias vezes' do
      conversa = conversa_esperando_cliente(fila_sem_regras)

      3.times { rodar_caixa }
      rodar_fila(fila_com_regras)

      expect(avisos(conversa, 'nudge').map(&:content)).to eq(['Ainda está aí? (caixa)'])
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
