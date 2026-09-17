require 'rails_helper'

# Impedimento: o ticket parou por algo externo e CONTINUA ABERTO. O que se prova
# aqui e justamente isso - que impedir nao encerra, nao muda status e nao tira o
# ticket da Mesa - alem do rastro que cada movimento deixa.
RSpec.describe TicketBlocking do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team) }

  describe '#block!' do
    it 'records who, when and why' do
      ticket.block!(user, reason: 'Aguardando retorno do fornecedor')

      expect(ticket.reload).to be_blocked
      expect(ticket.blocked_by).to eq(user)
      expect(ticket.blocked_at).to be_present
      expect(ticket.blocked_reason).to eq('Aguardando retorno do fornecedor')
    end

    # O ponto central da funcionalidade: impedimento nao e encerramento.
    it 'leaves the ticket open, on its desk and stage' do
      expect { ticket.block!(user, reason: 'Dependencia externa') }
        .not_to(change { ticket.reload.attributes.slice('status', 'team_id', 'ticket_column_id', 'assignee_id') })

      expect(ticket.reload.status).to eq('open')
    end

    it 'creates an internal comment with exactly the reason given' do
      expect { ticket.block!(user, reason: 'Cliente nao respondeu o e-mail') }
        .to change { ticket.ticket_comments.count }.by(1)

      expect(ticket.ticket_comments.order(:id).last).to have_attributes(
        content: 'Cliente nao respondeu o e-mail',
        user: user
      )
    end

    it 'records the movement in the history' do
      ticket.block!(user, reason: 'Aguardando licenca')

      activity = ticket.ticket_activities.find_by(activity_type: :blocked)
      expect(activity).to be_present
      expect(activity.user).to eq(user)
      expect(activity.new_value).to eq('Aguardando licenca')
    end

    # Sem motivo o impedimento nao ajuda ninguem a destrava-lo - e e o motivo que
    # vira o comentario interno.
    it 'refuses a blank reason and changes nothing' do
      expect { ticket.block!(user, reason: '   ') }.to raise_error(ArgumentError)

      expect(ticket.reload).not_to be_blocked
      expect(ticket.ticket_comments.count).to eq(0)
    end

    it 'refuses a nil reason' do
      expect { ticket.block!(user, reason: nil) }.to raise_error(ArgumentError)
    end
  end

  describe 'listing' do
    let!(:impedido) { create(:ticket, account: account, ticket_column: column, team: team) }
    let!(:normal) { create(:ticket, account: account, ticket_column: column, team: team) }

    before { impedido.block!(user, reason: 'Travado') }

    it 'returns only blocked tickets' do
      expect(Ticket.blocked).to include(impedido)
      expect(Ticket.blocked).not_to include(normal)
    end

    it 'excludes blocked tickets from the normal scope' do
      expect(Ticket.not_blocked).to include(normal)
      expect(Ticket.not_blocked).not_to include(impedido)
    end
  end

  describe '#unblock!' do
    before { ticket.block!(user, reason: 'Aguardando terceiro') }

    it 'clears the impediment and returns the ticket to the normal list' do
      ticket.unblock!(user)

      expect(ticket.reload).not_to be_blocked
      expect(ticket.blocked_by).to be_nil
      expect(ticket.blocked_reason).to be_nil
      expect(Ticket.blocked).not_to include(ticket)
      expect(Ticket.not_blocked).to include(ticket)
    end

    it 'records the removal in the history, naming the user' do
      outro = create(:user, account: account, role: :agent)
      ticket.unblock!(outro)

      activity = ticket.ticket_activities.find_by(activity_type: :unblocked)
      expect(activity.user).to eq(outro)
      expect(activity.previous_value).to eq('Aguardando terceiro')

      expect(ticket.ticket_comments.order(:id).last.content).to include(outro.name)
    end

    it 'keeps the ticket open' do
      expect { ticket.unblock!(user) }.not_to(change { ticket.reload.status })
    end

    # Idempotente de proposito: retirar duas vezes nao deve sujar o historico com
    # uma remocao que nao aconteceu.
    it 'does nothing when the ticket is not blocked' do
      ticket.unblock!(user)

      expect { ticket.unblock!(user) }.not_to(change { ticket.ticket_activities.count })
    end
  end
end
