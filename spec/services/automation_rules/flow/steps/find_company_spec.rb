require 'rails_helper'

RSpec.describe AutomationRules::Flow::Steps::FindCompany do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:automation_rule) { create(:automation_rule, account: account, flow_steps: []) }
  let(:run) { create(:automation_flow_run, account: account, automation_rule: automation_rule, conversation: conversation) }
  let(:resolver) { AutomationRules::Flow::VariableResolver.new(run) }
  let(:step) do
    { 'id' => 's2', 'type' => 'find_company', 'params' => { 'cnpj_from' => 'resposta.cnpj' },
      'next' => 's3', 'branches' => { 'not_found' => 's6' } }
  end
  # `client_level` e recalculado automaticamente por `compute_client_level` -
  # nao da pra fixar aqui, entao os testes comparam com `company.client_level`.
  # CNPJ de teste com digito verificador valido (Company valida o checksum).
  let(:company) { create(:company, account: account, cnpj: '11222333000181') }

  def perform_with(cnpj)
    run.write_variable('resposta.cnpj', cnpj)
    described_class.new(run: run, step: step, resolver: resolver).perform
  end

  before { company }

  # Cenario 6: CNPJ com pontuacao.
  it 'encontra a empresa quando o CNPJ vem com pontuacao' do
    result = perform_with('11.222.333/0001-81')

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s3')
    expect(run.read_variable('empresa.id')).to eq(company.id)
    expect(run.read_variable('empresa.nome')).to eq(company.name)
    expect(run.read_variable('empresa.nivel')).to eq(company.client_level)
  end

  # Cenario 7: CNPJ sem pontuacao - mesma empresa.
  it 'encontra a mesma empresa quando o CNPJ vem sem pontuacao' do
    result = perform_with('11222333000181')

    expect(result.action).to eq(:continue)
    expect(run.read_variable('empresa.id')).to eq(company.id)
  end

  # Cenario 4: CNPJ nao encontrado.
  it 'segue pelo branch not_found quando o CNPJ nao existe na base' do
    result = perform_with('00.000.000/0000-00')

    expect(result.action).to eq(:continue)
    expect(result.next_step_id).to eq('s6')
    expect(result.result[:reason]).to eq('nao_encontrada')
    expect(run.read_variable('empresa.id')).to be_nil
  end

  it 'vai direto pro handoff quando nao ha branch not_found configurado' do
    step['branches'] = {}

    result = perform_with('00.000.000/0000-00')

    expect(result.action).to eq(:handoff)
  end
end
