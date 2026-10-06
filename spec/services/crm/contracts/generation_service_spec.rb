require 'rails_helper'

RSpec.describe Crm::Contracts::GenerationService do
  let(:account) { create(:account) }
  let(:client) { create(:crm_client, account: account, name: 'Duesoft Sistemas', cnpj: '00.000.000/0001-00') }
  let(:template) { create(:crm_contract_template, account: account) }

  before do
    stub_pdf_conversion!
    template.file.attach(
      io: File.open(build_minimal_docx('[[cliente_razao_social]] - [[tipo_licenca]]')),
      filename: 'modelo.docx', content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    )
  end

  # O PONTO CENTRAL do pedido: os 5 tokens de identidade do cliente nunca
  # podem ser sobrescritos pelo que foi digitado na tela de geracao.
  it 'nao deixa um valor digitado manualmente sobrescrever um token travado' do
    contract = described_class.new(
      template: template, client: client, data: { 'cliente_razao_social' => 'Nome Forjado' }
    ).perform

    expect(contract.data['cliente_razao_social']).to eq('Duesoft Sistemas')
  end

  it 'continua aceitando valor manual para um token que nao e travado' do
    contract = described_class.new(
      template: template, client: client, data: { 'tipo_licenca' => 'Mensal' }
    ).perform

    expect(contract.data['tipo_licenca']).to eq('Mensal')
  end
end
