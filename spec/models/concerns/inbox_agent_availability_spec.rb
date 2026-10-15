require 'rails_helper'

RSpec.describe InboxAgentAvailability do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:member_online) { create(:inbox_member, inbox: inbox) }
  let!(:member_on_lunch) { create(:inbox_member, inbox: inbox) }

  before do
    create(:account_user, account: account, user: member_online.user)
    create(:account_user, account: account, user: member_on_lunch.user,
                          lunch_start_hour: 11, lunch_start_minutes: 0, lunch_end_hour: 13, lunch_end_minutes: 0)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
      member_online.user_id.to_s => 'online',
      member_on_lunch.user_id.to_s => 'online'
    )
  end

  describe '#available_agents' do
    # Pedido: 20 minutos antes do horario de almoco cadastrado no agente, ele
    # para de entrar na distribuicao automatica - sem precisar ficar offline.
    it 'excludes an online agent who is inside their lunch blackout window' do
      travel_to(Time.find_zone!('America/Sao_Paulo').local(2026, 10, 15, 12, 0)) do
        expect(inbox.available_agents.map(&:user_id)).to contain_exactly(member_online.user_id)
      end
    end

    it 'includes the agent again once their lunch break has ended' do
      travel_to(Time.find_zone!('America/Sao_Paulo').local(2026, 10, 15, 13, 1)) do
        expect(inbox.available_agents.map(&:user_id)).to contain_exactly(member_online.user_id, member_on_lunch.user_id)
      end
    end
  end

  describe '#member_ids_with_assignment_capacity' do
    it 'excludes an agent on their lunch blackout window' do
      travel_to(Time.find_zone!('America/Sao_Paulo').local(2026, 10, 15, 12, 0)) do
        expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(member_online.user_id)
      end
    end
  end
end
