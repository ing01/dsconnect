require 'rails_helper'

# Valida de ponta a ponta o fluxo completo pedido: um agente pode trocar o
# proprio status (online/busy/offline) e isso afeta quem recebe chamado novo;
# o horario de almoco se soma a essa regra sem conflito. Sem mocks no
# OnlineStatusTracker - o status passa pelo Redis de verdade, exatamente como
# o `PATCH /profile/availability` faz na aplicacao real (ver
# ProfilesController#availability -> AccountUser#update! -> after_save
# update_presence_in_redis).
# rubocop:disable RSpec/DescribeClass -- cruza varios services/concerns de proposito
RSpec.describe 'Horario de almoco + status do agente na distribuicao automatica' do
  let!(:account) { create(:account) }
  let!(:offline_agent) { agent_with_status('offline') }
  let!(:busy_agent) { agent_with_status('busy') }
  let!(:lunch_agent) do
    agent_with_status('online', lunch: { lunch_start_hour: 11, lunch_start_minutes: 0,
                                         lunch_end_hour: 13, lunch_end_minutes: 0 })
  end
  let!(:available_agent) { agent_with_status('online') }
  let!(:inbox) { create(:inbox, account: account) }

  def agent_with_status(status, lunch: nil)
    user = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: user)
    account_user = AccountUser.find_by!(account: account, user: user)
    account_user.update!(availability: status, **(lunch || {}))
    # `OnlineStatusTracker.get_available_users` so considera quem tem presenca
    # de verdade (heartbeat do navegador aberto, `update_presence`) - sem
    # isso o usuario nem aparece no Redis, independente do status escolhido.
    # `set_status` por si so (o que o `after_save` do AccountUser faz) nao
    # basta - ele so grava o VALOR do status de quem ja esta presente.
    OnlineStatusTracker.update_presence(account.id, 'User', user.id)
    OnlineStatusTracker.set_status(account.id, user.id, status)
    user
  end

  around do |example|
    travel_to(Time.find_zone!('America/Sao_Paulo').local(2026, 10, 15, 12, 0)) { example.run }
  end

  shared_examples 'respeita status e almoco' do
    it 'exclui o agente offline' do
      expect(eligible_agent_ids).not_to include(offline_agent.id)
    end

    it 'exclui o agente ocupado' do
      expect(eligible_agent_ids).not_to include(busy_agent.id)
    end

    it 'exclui o agente online que esta no horario de almoco' do
      expect(eligible_agent_ids).not_to include(lunch_agent.id)
    end

    it 'inclui o agente online sem almoco configurado' do
      expect(eligible_agent_ids).to include(available_agent.id)
    end
  end

  describe 'fluxo V2 (politica de atribuicao)' do
    before { account.enable_features('assignment_v2') }

    let(:eligible_agent_ids) { inbox.available_agents.map(&:user_id) }

    it_behaves_like 'respeita status e almoco'

    it 'atribui a conversa nova so para quem esta realmente disponivel agora' do
      conversation = create(:conversation, inbox: inbox, account: account, assignee: nil, status: 'open')

      AutoAssignment::AssignmentService.new(inbox: inbox).perform_bulk_assignment

      expect(conversation.reload.assignee).to eq(available_agent)
    end

    it 'depois que o almoco termina, o agente volta a disputar a distribuicao sem nenhuma acao manual' do
      travel_to Time.find_zone!('America/Sao_Paulo').local(2026, 10, 15, 13, 1)
      # O heartbeat de presenca expira so' (`PRESENCE_DURATION`) - no app de
      # verdade a aba aberta renova isso sozinha a cada poucos segundos,
      # entao refaco aqui pra simular "continuou logado o tempo todo".
      OnlineStatusTracker.update_presence(account.id, 'User', lunch_agent.id)

      expect(inbox.available_agents.map(&:user_id)).to include(lunch_agent.id)
    end
  end

  describe 'fluxo legado (sem assignment_v2)' do
    # `assignment_v2` vem HABILITADO por padrao pra toda conta (ver
    # config/features.yml) - precisa desligar explicitamente pra exercitar
    # o caminho antigo de verdade.
    before { account.disable_features!('assignment_v2') }

    let(:eligible_agent_ids) do
      allowed = inbox.member_ids_with_assignment_capacity.map(&:to_s)
      AutoAssignment::AgentAssignmentService.new(
        conversation: create(:conversation, inbox: inbox, account: account), allowed_agent_ids: allowed
      ).send(:allowed_online_agent_ids).map(&:to_i)
    end

    it_behaves_like 'respeita status e almoco'

    it 'atribui a conversa nova so para quem esta realmente disponivel agora' do
      conversation = create(:conversation, inbox: inbox, account: account, assignee: nil, status: 'open')

      AutoAssignment::AgentAssignmentService.new(
        conversation: conversation, allowed_agent_ids: inbox.member_ids_with_assignment_capacity.map(&:to_s)
      ).perform

      expect(conversation.reload.assignee).to eq(available_agent)
    end
  end

  describe 'o proprio agente trocando de status (ProfilesController#availability)' do
    it 'ao ficar offline, para de entrar na distribuicao imediatamente' do
      expect(inbox.available_agents.map(&:user_id)).to include(available_agent.id)

      AccountUser.find_by!(account: account, user: available_agent).update!(availability: 'offline')

      expect(inbox.available_agents.map(&:user_id)).not_to include(available_agent.id)
    end

    it 'ao voltar para online, volta a entrar na distribuicao imediatamente' do
      AccountUser.find_by!(account: account, user: available_agent).update!(availability: 'offline')
      expect(inbox.available_agents.map(&:user_id)).not_to include(available_agent.id)

      AccountUser.find_by!(account: account, user: available_agent).update!(availability: 'online')

      expect(inbox.available_agents.map(&:user_id)).to include(available_agent.id)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
