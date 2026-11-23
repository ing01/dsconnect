require 'rails_helper'

# Quando um impedimento e removido (ou concluido), o responsavel pelo ticket FILHO e avisado.
RSpec.describe 'Aviso de impedimento removido ao responsavel do ticket filho' do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:analyst) { create(:user, account: account, role: :agent, name: 'Analista') }
  let(:dev) { create(:user, account: account, role: :agent, name: 'Dev') }
  let(:other_dev) { create(:user, account: account, role: :agent, name: 'Outro Dev') }
  let(:parent) { create(:ticket, account: account, ticket_column: column, team: team, assignee: analyst) }
  let(:child) { create(:ticket, account: account, ticket_column: column, team: team, parent: parent, assignee: dev, title: 'Ajustar relatorio') }

  def notices_for(user)
    user.notifications.where(notification_type: 'ticket_impediment_released')
  end

  describe 'the child ticket own impediment' do
    before { child.block!(dev, reason: 'Sem acesso ao ambiente') }

    it 'notifies the assignee of the child when somebody else removes it' do
      expect { child.unblock!(analyst, resolution: 'Acesso liberado') }.to change { notices_for(dev).count }.by(1)

      notice = notices_for(dev).last
      expect(notice.primary_actor).to eq(child)
      expect(notice.secondary_actor).to eq(child)
      expect(notice.push_target_path).to eq("/app/accounts/#{account.id}/tickets/#{child.id}")
    end

    it 'does not notify the person who removed it' do
      expect { child.unblock!(dev) }.not_to(change { notices_for(dev).count })
    end

    it 'has the title and body to show on the bell' do
      child.unblock!(analyst)

      notice = notices_for(dev).last
      expect(notice.push_message_title).to include("##{child.display_id}")
      expect(notice.push_message_body).to include('Ajustar relatorio')
    end

    it 'does not notify anybody when the child has no assignee' do
      child.update!(assignee: nil)

      expect { child.unblock!(analyst) }.not_to change(Notification, :count)
    end

  end

  describe 'the parent impediment removed by the analyst' do
    it 'notifies only the child it came from when the impediment came from a child' do
      other_child = create(:ticket, account: account, ticket_column: column, team: team, parent: parent, assignee: other_dev)
      child.block!(dev, reason: 'Aguardando API')

      expect { parent.reload.unblock!(analyst, resolution: 'Resolvido') }.to change { notices_for(dev).count }.by(1)

      expect(notices_for(other_dev).count).to eq(0)
      notice = notices_for(dev).last
      expect(notice.primary_actor).to eq(child)
      expect(notice.secondary_actor).to eq(parent)
      expect(other_child).to be_present
    end

    it 'notifies every open child when the impediment was the parent own' do
      other_child = create(:ticket, account: account, ticket_column: column, team: team, parent: parent, assignee: other_dev)
      child.update!(assignee: dev)
      parent.block!(analyst, reason: 'Aguardando o cliente')

      parent.unblock!(analyst)

      expect(notices_for(dev).count).to eq(1)
      expect(notices_for(other_dev).count).to eq(1)
      expect(notices_for(analyst).count).to eq(0)
      expect(other_child).to be_present
    end

    it 'does not notify the assignee of a child that is already finished' do
      child.update!(status: :closed)
      parent.block!(analyst, reason: 'Aguardando o cliente')

      expect { parent.unblock!(analyst) }.not_to(change { notices_for(dev).count })
    end

    it 'sends one notice per person even with several children under the same assignee' do
      create(:ticket, account: account, ticket_column: column, team: team, parent: parent, assignee: dev)
      child.update!(assignee: dev)
      parent.block!(analyst, reason: 'Aguardando o cliente')

      expect { parent.unblock!(analyst) }.to change { notices_for(dev).count }.by(1)
    end
  end

  describe 'when the child releases the parent in cascade' do
    it 'notifies the child only once, by its own removal, and never the other children' do
      create(:ticket, account: account, ticket_column: column, team: team, parent: parent, assignee: other_dev)
      child.block!(dev, reason: 'Aguardando API')

      child.unblock!(analyst)

      expect(parent.reload).not_to be_blocked
      expect(notices_for(dev).count).to eq(1)
      expect(notices_for(other_dev).count).to eq(0)
    end
  end

  it 'never breaks the removal of the impediment when the notice fails' do
    child.block!(dev, reason: 'Sem acesso')
    allow(Tickets::ImpedimentReleasedNotificationBuilder).to receive(:new).and_raise(StandardError, 'falhou')

    expect { child.unblock!(analyst) }.not_to raise_error
    expect(child.reload).not_to be_blocked
  end
end
