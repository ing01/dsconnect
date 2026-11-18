require 'rails_helper'

# A Automacao de Estagio escuta `ticket.moved`. A transferencia (API de
# Integracao, tela de fechamento) termina com um `reload` e, na API, ainda salva o
# ticket de novo na mesma transacao - nada disso pode fazer o evento sair como
# `ticket.updated`, senao o Estagio de destino nao roda a automacao dele.
RSpec.describe Tickets::TransferService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:origin) { create(:ticket_column, team: team) }
  let(:finished) { create(:ticket_column, team: team, name: 'Finalizado dev') }
  let(:ticket) { create(:ticket, account: account, ticket_column: origin, team: team) }

  before { allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original }

  def transfer(**attributes)
    described_class.new(ticket: ticket, user: nil, attributes: attributes).perform
  end

  it 'dispatches ticket.moved when the Estagio changes' do
    transfer(team_id: team.id, ticket_column_id: finished.id)

    expect(Rails.configuration.dispatcher).to have_received(:dispatch)
      .with(Events::Types::TICKET_MOVED, anything, ticket: ticket)
  end

  it 'still dispatches ticket.moved when the ticket is saved again in the same transaction' do
    ticket # criado antes da transacao
    ActiveRecord::Base.transaction do
      transfer(team_id: team.id, ticket_column_id: finished.id)
      ticket.update!(priority: :urgent)
    end

    expect(Rails.configuration.dispatcher).to have_received(:dispatch)
      .with(Events::Types::TICKET_MOVED, anything, ticket: ticket)
  end

  it 'does not dispatch ticket.moved when the Estagio stays the same' do
    transfer(team_id: team.id, ticket_column_id: origin.id, priority: 'urgent')

    expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
      .with(Events::Types::TICKET_MOVED, anything, anything)
  end

  it 'enqueues the customer messages with the previous Mesa when the Mesa changed' do
    create(:ticket_column, team: other_team)
    target = other_team.ticket_columns.first
    TicketCustomerNoticeRule.create!(account: account, kind: 'team', name: 'Mudou', body: 'Oi', team: other_team)

    expect { transfer(team_id: other_team.id, ticket_column_id: target.id) }
      .to have_enqueued_job(Tickets::CustomerNoticeJob).with(ticket.id, target.id, team.id, other_team.id)
  end
end
