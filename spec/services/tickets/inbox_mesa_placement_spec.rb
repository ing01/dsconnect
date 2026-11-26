require 'rails_helper'

# Ticket nascido de uma conversa vai para a Mesa da Fila padrao da caixa:
# caixa Comercial -> Mesa Comercial, caixa Especialista -> Mesa Especialista.
RSpec.describe Tickets::InboxMesaPlacement do
  let(:account) { create(:account) }
  let!(:suporte) { create(:team, account: account, name: 'suporte') }
  let(:comercial) { create(:team, account: account, name: 'comercial') }
  let(:fila_comercial) { ServiceQueue.create!(account: account, team: comercial, name: 'Comercial') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  context 'quando a caixa tem Fila padrao' do
    before { inbox.update!(default_queue: fila_comercial) }

    it 'usa a Mesa da fila, no Estagio Pendente' do
      attrs = described_class.new(conversation: conversation).attributes

      expect(attrs[:team_id]).to eq(comercial.id)
      expect(attrs[:ticket_column_id]).to eq(comercial.ticket_columns.find_by(kind: 'pending').id)
      expect(attrs[:ticket_category_id]).to eq(comercial.ticket_categories.first.id)
    end

    it 'mantem a categoria pedida quando ela e da Mesa da fila' do
      categoria = comercial.ticket_categories.last
      attrs = described_class.new(conversation: conversation).attributes(ticket_category_id: categoria.id)

      expect(attrs[:ticket_category_id]).to eq(categoria.id)
    end

    it 'troca a categoria de outra Mesa pela primeira da Mesa da fila' do
      attrs = described_class.new(conversation: conversation)
                             .attributes(ticket_category_id: suporte.ticket_categories.first.id)

      expect(attrs[:ticket_category_id]).to eq(comercial.ticket_categories.first.id)
    end

    it 'ignora a fila inativa' do
      fila_comercial.update!(active: false)

      expect(described_class.new(conversation: conversation).attributes).to eq({})
    end
  end

  it 'nao decide nada quando a caixa nao tem Fila padrao' do
    expect(described_class.new(conversation: conversation).attributes).to eq({})
  end

  describe 'ticket automatico do WhatsApp' do
    it 'nasce na Mesa da fila da caixa, e nao na primeira Mesa da conta' do
      inbox.update!(default_queue: fila_comercial)

      ticket = Tickets::WhatsappAutoCreationService.new(conversation: conversation).perform

      expect(ticket.team).to eq(comercial)
    end

    it 'continua na Mesa padrao da conta sem Fila padrao na caixa' do
      ticket = Tickets::WhatsappAutoCreationService.new(conversation: conversation).perform

      expect(ticket.team).to eq(suporte)
    end
  end
end
