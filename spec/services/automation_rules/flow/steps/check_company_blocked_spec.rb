require 'rails_helper'

RSpec.describe AutomationRules::Flow::Steps::CheckCompanyBlocked do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:automation_rule) { create(:automation_rule, account: account, flow_steps: []) }
  let(:run) { create(:automation_flow_run, account: account, automation_rule: automation_rule, conversation: conversation) }
  let(:resolver) { AutomationRules::Flow::VariableResolver.new(run) }
  let(:step) do
    { 'id' => 's3', 'type' => 'check_company_blocked', 'params' => {},
      'next' => 's4', 'branches' => { 'blocked' => 's13' } }
  end

  def perform_for(company)
    run.write_variable('empresa.id', company.id)
    described_class.new(run: run, step: step, resolver: resolver).perform
  end

  # Cenario 5: empresa bloqueada.
  it 'segue pelo branch blocked quando a empresa esta bloqueada' do
    company = create(:company, account: account, blocked: true)

    result = perform_for(company)

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s13')
    expect(result.result[:blocked]).to be true
  end

  it 'continua normalmente quando a empresa esta habilitada' do
    company = create(:company, account: account, blocked: false)

    result = perform_for(company)

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s4')
    expect(result.result[:blocked]).to be false
  end
end
