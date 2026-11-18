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

    # O comentario anuncia o que aconteceu e so depois da o motivo: lido no meio
    # do historico, o texto cru nao diria de que movimento se trata.
    it 'creates an internal comment carrying the reason under a label' do
      expect { ticket.block!(user, reason: 'Cliente nao respondeu o e-mail') }
        .to change { ticket.ticket_comments.count }.by(1)

      comentario = ticket.ticket_comments.order(:id).last
      expect(comentario.user).to eq(user)
      expect(comentario.content).to include('Cliente nao respondeu o e-mail')
      expect(comentario.content).to start_with(
        I18n.t('tickets.impediment.recorded_comment', reason: '').strip
      )
    end

    # O campo guarda o texto limpo: e ele que a tela mostra no aviso, sem rotulo.
    it 'stores the raw reason on the ticket, without the label' do
      ticket.block!(user, reason: 'Cliente nao respondeu o e-mail')

      expect(ticket.reload.blocked_reason).to eq('Cliente nao respondeu o e-mail')
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

  # Impedimento de ticket FILHO sobe para o PAI, e sai junto com ele.
  describe 'parent and child' do
    let(:parent) { create(:ticket, account: account, ticket_column: column, team: team) }
    let(:child) { create(:ticket, account: account, ticket_column: column, team: team, parent: parent) }

    it 'blocks the parent too, saying which child it came from' do
      child.block!(user, reason: 'Aguardando a API do fornecedor')

      expect(parent.reload).to be_blocked
      expect(parent.blocked_by_child_id).to eq(child.id)
      expect(parent.blocked_reason).to eq(
        I18n.t('tickets.impediment.from_child_reason', display_id: child.display_id, reason: 'Aguardando a API do fornecedor')
      )
      expect(parent.blocked_reason).to include("##{child.display_id}")
    end

    it 'records the impediment in the history and the comments of the parent' do
      child.block!(user, reason: 'Sem retorno do cliente')

      expect(parent.ticket_activities.find_by(activity_type: :blocked).new_value).to include('Sem retorno do cliente')
      expect(parent.ticket_comments.order(:id).last.content).to include('Sem retorno do cliente')
    end

    it 'leaves the parent open, on its desk and stage' do
      child.block!(user, reason: 'Dependencia externa')

      expect(parent.reload.attributes.slice('status', 'team_id', 'ticket_column_id')).to eq(
        'status' => 'open', 'team_id' => team.id, 'ticket_column_id' => column.id
      )
    end

    it 'does not block the child when only the parent is blocked' do
      parent.block!(user, reason: 'Algo no pai')

      expect(child.reload).not_to be_blocked
    end

    it 'keeps an impediment the parent already had, only commenting the child' do
      parent.block!(user, reason: 'Impedimento proprio do pai')

      child.block!(user, reason: 'Do filho')

      expect(parent.reload.blocked_reason).to eq('Impedimento proprio do pai')
      expect(parent.blocked_by_child_id).to be_nil
      expect(parent.ticket_comments.order(:id).last.content).to include('Do filho')
    end

    it 'does not touch a finished parent' do
      parent.update_columns(status: Ticket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations

      expect { child.block!(user, reason: 'Algo') }.not_to raise_error
      expect(parent.reload).not_to be_blocked
    end

    it 'goes up through every level' do
      avo = create(:ticket, account: account, ticket_column: column, team: team)
      parent.update!(parent: avo)

      child.block!(user, reason: 'Travou embaixo')

      expect(avo.reload).to be_blocked
    end

    describe 'removing the impediment' do
      before { child.block!(user, reason: 'Aguardando fornecedor') }

      it 'frees the parent along with the child' do
        child.unblock!(user, resolution: 'O fornecedor liberou a API')

        expect(child.reload).not_to be_blocked
        expect(parent.reload).not_to be_blocked
        expect(parent.blocked_by_child_id).to be_nil
      end

      it 'records the resolution in the comments and the history of BOTH tickets' do
        child.unblock!(user, resolution: 'O fornecedor liberou a API')

        [child, parent].each do |ticket|
          expect(ticket.ticket_comments.order(:id).last.content).to include('O fornecedor liberou a API')
          activity = ticket.ticket_activities.find_by(activity_type: :unblocked)
          expect(activity.new_value).to eq('O fornecedor liberou a API')
          expect(activity.previous_value).to include('Aguardando fornecedor')
        end
      end

      it 'works without a resolution, as before' do
        child.unblock!(user)

        expect(parent.reload).not_to be_blocked
        expect(child.ticket_activities.find_by(activity_type: :unblocked).new_value).to be_nil
      end

      it 'does not free a parent whose impediment is its own' do
        parent.unblock!(user)
        parent.block!(user, reason: 'Do proprio pai')

        child.unblock!(user, resolution: 'Resolvido')

        expect(parent.reload).to be_blocked
        expect(parent.blocked_reason).to eq('Do proprio pai')
      end

      it 'keeps the parent blocked while another child is still blocked' do
        outro = create(:ticket, account: account, ticket_column: column, team: team, parent: parent)
        outro.block!(user, reason: 'Outro bloqueio')

        child.unblock!(user, resolution: 'Resolvido')

        expect(parent.reload).to be_blocked
        expect(parent.blocked_by_child_id).to eq(outro.id)
        expect(parent.blocked_reason).to include('Outro bloqueio')

        outro.unblock!(user, resolution: 'Tambem resolvido')
        expect(parent.reload).not_to be_blocked
      end

      it 'frees the parent from a parent unblock without freeing the child' do
        parent.unblock!(user, resolution: 'Liberado no pai')

        expect(parent.reload).not_to be_blocked
        expect(child.reload).to be_blocked
      end
    end
  end
end
