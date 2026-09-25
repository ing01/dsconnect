require 'rails_helper'

RSpec.describe AutomationRules::Flow::Steps::CheckProblemClarity do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:automation_rule) { create(:automation_rule, account: account, flow_steps: []) }
  let(:run) { create(:automation_flow_run, account: account, automation_rule: automation_rule, conversation: conversation) }
  let(:resolver) { AutomationRules::Flow::VariableResolver.new(run) }
  let(:step) do
    { 'id' => 's9', 'type' => 'check_problem_clarity', 'params' => {}, 'next' => 's7', 'branches' => { 'unclear' => 's10' } }
  end

  def stub_clarity(claro)
    classifier = instance_double(Captain::Llm::ProblemClarityClassifierService)
    allow(Captain::Llm::ProblemClarityClassifierService).to receive(:new).and_return(classifier)
    allow(classifier).to receive(:classify).and_return('claro' => claro)
  end

  it 'segue direto pro proximo passo quando o problema esta claro' do
    stub_clarity(true)

    result = described_class.new(run: run, step: step, resolver: resolver).perform

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s7')
  end

  it 'segue pelo branch unclear quando falta informacao' do
    stub_clarity(false)

    result = described_class.new(run: run, step: step, resolver: resolver).perform

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s10')
  end

  it 'segue em frente (falha aberta) quando a IA nao classifica nada' do
    stub_clarity(nil)

    result = described_class.new(run: run, step: step, resolver: resolver).perform

    expect(result.next_step_id).to eq('s7')
  end

  it 'segue em frente quando nao ha branch unclear configurado' do
    step['branches'] = {}
    stub_clarity(false)

    result = described_class.new(run: run, step: step, resolver: resolver).perform

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s7')
  end
end
