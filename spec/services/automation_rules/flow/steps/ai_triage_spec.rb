require 'rails_helper'

RSpec.describe AutomationRules::Flow::Steps::AiTriage do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:team) { create(:team, account: account) }
  let(:ticket_column) { create(:ticket_column, team: team) }
  let(:ticket_category) { team.ticket_categories.first }
  # `client_level` e sempre recalculado por `compute_client_level` a partir do
  # valor de contrato - uma empresa sem contrato/faturamento cai no nivel 1
  # (baixa) por padrao, e e exatamente o piso que estes testes precisam.
  let(:company) { create(:company, account: account) }
  let(:queue_low) { ServiceQueue.create!(account: account, team: team, name: 'Suporte N1', distribution_strategy: 'manual') }
  let(:queue_high) { ServiceQueue.create!(account: account, team: team, name: 'Suporte N2', distribution_strategy: 'manual') }
  let(:automation_rule) { create(:automation_rule, account: account, flow_steps: []) }
  let(:run) { create(:automation_flow_run, account: account, automation_rule: automation_rule, conversation: conversation) }
  let(:resolver) { AutomationRules::Flow::VariableResolver.new(run) }
  let(:step) do
    { 'id' => 's8', 'type' => 'ai_triage', 'params' => { 'team_id' => team.id }, 'next' => nil, 'branches' => {} }
  end

  before do
    account.update!(helpdesk_queue_low_id: queue_low.id, helpdesk_queue_high_id: queue_high.id)
    run.write_variable('empresa.id', company.id)
    run.write_variable('empresa.nome', company.name)
    run.write_variable('empresa.cnpj', company.cnpj)
    run.write_variable('empresa.nivel', company.client_level)
    # `create_ticket` roda antes de `ai_triage` no fluxo de verdade - aqui so
    # precisamos que exista um ticket com esses parametros pra reaproveitar.
    step_create_ticket = { 'id' => 's7', 'type' => 'create_ticket',
                            'params' => { 'title' => 'Teste', 'team_id' => team.id,
                                          'ticket_column_id' => ticket_column.id,
                                          'ticket_category_id' => ticket_category.id } }
    AutomationRules::Flow::Steps::CreateTicket.new(run: run, step: step_create_ticket, resolver: resolver).perform
  end

  def perform_with_priority(prioridade)
    classifier = instance_double(Captain::Llm::TriagePriorityClassifierService)
    allow(Captain::Llm::TriagePriorityClassifierService).to receive(:new).and_return(classifier)
    allow(classifier).to receive(:classify).and_return(
      'prioridade' => prioridade, 'resumo_problema' => 'Resumo', 'acao_sugerida' => 'Ação', 'model' => 'gemini-3.6-flash'
    )

    described_class.new(run: run, step: step, resolver: resolver).perform
  end

  # Cenario 1: prioridade alta -> ticket alta, fila N2.
  it 'classifica alta, cria/atualiza o ticket com prioridade high e roteia pra fila alta' do
    result = perform_with_priority('alta')

    expect(result.action).to eq(:handoff)
    expect(run.ticket.reload.priority).to eq('high')
    expect(conversation.reload.priority).to eq('high')
    expect(conversation.queue_id).to eq(queue_high.id)
    expect(conversation.team_id).to eq(team.id)
  end

  # Cenario 2: prioridade media -> ticket media, fila N1.
  it 'classifica media, cria/atualiza o ticket com prioridade medium e roteia pra fila baixa/media' do
    perform_with_priority('media')

    expect(run.ticket.reload.priority).to eq('medium')
    expect(conversation.reload.queue_id).to eq(queue_low.id)
  end

  # Cenario 3: prioridade baixa -> ticket baixa, fila N1.
  it 'classifica baixa, cria/atualiza o ticket com prioridade low e roteia pra fila baixa/media' do
    perform_with_priority('baixa')

    expect(run.ticket.reload.priority).to eq('low')
    expect(conversation.reload.queue_id).to eq(queue_low.id)
  end

  it 'continua informando o numero do ticket criado' do
    perform_with_priority('baixa')

    ticket_number = run.ticket.reload.display_id
    expect(conversation.messages.where(message_type: :outgoing).map(&:content)).to include(
      a_string_including("##{ticket_number}")
    )
  end

  it 'informa a prioridade na mensagem final, sem mencionar criterios internos' do
    perform_with_priority('alta')

    last_message = conversation.messages.where(message_type: :outgoing).order(:created_at).first
    expect(last_message.content).to include('ALTA')
  end
end
