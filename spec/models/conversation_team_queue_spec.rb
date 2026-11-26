require 'rails_helper'

# Trocar o Time da conversa leva a Fila junto: e pela Fila que o Painel de Conversas
# e a aba "Na fila" contam.
RSpec.describe Conversation do
  describe 'fila acompanha o time' do
    let(:account) { create(:account) }
    let(:suporte) { create(:team, account: account, name: 'suporte') }
    let(:especialista) { create(:team, account: account, name: 'especialista') }
    let(:fila_suporte) { ServiceQueue.create!(account: account, team: suporte, name: 'Suporte') }
    let!(:fila_especialista) { ServiceQueue.create!(account: account, team: especialista, name: 'Especialista') }
    let(:conversation) { create(:conversation, account: account, team: suporte, queue: fila_suporte, assignee: nil) }

    def contagem(queue)
      setting = ConversationPanelSetting.for(account)
      ConversationPanel::Builder.new(account, setting: setting, queue_id: queue.id).perform[:counts][:total]
    end

    it 'passa para a fila do time novo, e o painel conta la' do
      conversation.update!(team: especialista)

      expect(conversation.reload.queue).to eq(fila_especialista)
      expect(contagem(fila_especialista)).to eq(1)
      expect(contagem(fila_suporte)).to eq(0)
    end

    it 'mantem a fila quando o time novo nao tem fila' do
      conversation.update!(team: create(:team, account: account, name: 'sem fila'))

      expect(conversation.reload.queue).to eq(fila_suporte)
    end

    it 'mantem a fila quando o time novo tem mais de uma' do
      ServiceQueue.create!(account: account, team: especialista, name: 'Especialista 2')

      conversation.update!(team: especialista)

      expect(conversation.reload.queue).to eq(fila_suporte)
    end

    it 'ignora fila inativa do time novo' do
      fila_especialista.update!(active: false)

      conversation.update!(team: especialista)

      expect(conversation.reload.queue).to eq(fila_suporte)
    end

    it 'respeita a fila escolhida junto com o time' do
      outra = ServiceQueue.create!(account: account, team: suporte, name: 'Suporte N2')

      conversation.update!(team: especialista, queue: outra)

      expect(conversation.reload.queue).to eq(outra)
    end

    it 'nao poe em fila uma conversa que estava sem fila' do
      solta = create(:conversation, account: account, team: suporte)

      solta.update!(team: especialista)

      expect(solta.reload.queue_id).to be_nil
    end

    it 'nao mexe na fila quando o time e removido' do
      conversation.update!(team: nil)

      expect(conversation.reload.queue).to eq(fila_suporte)
    end
  end
end
