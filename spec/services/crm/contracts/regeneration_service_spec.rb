require 'rails_helper'

RSpec.describe Crm::Contracts::RegenerationService do
  let(:account) { create(:account) }
  let(:client) { create(:crm_client, account: account, representative_name: 'Representante Antigo') }
  let(:template) { create(:crm_contract_template, account: account) }
  let(:contract) do
    create(:crm_generated_contract, account: account, template: template, client: client,
                                    data: { 'cliente_razao_social' => client.name, 'representante_nome' => 'Representante Antigo',
                                            'tipo_licenca' => 'Mensal' })
  end

  before do
    stub_pdf_conversion!
    template.file.attach(
      io: File.open(build_minimal_docx('[[representante_nome]] - [[tipo_licenca]]')),
      filename: 'modelo.docx', content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    )
    contract.pdf.attach(io: StringIO.new('%PDF antigo'), filename: 'antigo.pdf', content_type: 'application/pdf')
    contract.docx.attach(io: StringIO.new('docx antigo'), filename: 'antigo.docx', content_type: 'application/octet-stream')
  end

  it 'atualiza o token de representante com o valor atual do cliente' do
    client.update!(representative_name: 'Representante Novo')

    described_class.new(contract: contract, reason: 'representative_change').perform

    expect(contract.reload.data['representante_nome']).to eq('Representante Novo')
  end

  it 'preserva campos digitados manualmente que nao sao de representante/identidade' do
    client.update!(representative_name: 'Representante Novo')

    described_class.new(contract: contract, reason: 'representative_change').perform

    expect(contract.reload.data['tipo_licenca']).to eq('Mensal')
  end

  it 'arquiva a versao anterior numa revisao, com o data e os arquivos antigos' do
    client.update!(representative_name: 'Representante Novo')

    expect { described_class.new(contract: contract, reason: 'representative_change').perform }
      .to change { contract.revisions.count }.by(1)

    revisao = contract.revisions.last
    expect(revisao.data['representante_nome']).to eq('Representante Antigo')
    expect(revisao.reason).to eq('representative_change')
    expect(revisao.pdf).to be_attached
    expect(revisao.docx).to be_attached
  end

  it 'substitui o pdf/docx do proprio contrato pelos novos' do
    pdf_blob_antigo = contract.pdf.blob.id

    described_class.new(contract: contract, reason: 'representative_change').perform

    expect(contract.reload.pdf.blob.id).not_to eq(pdf_blob_antigo)
  end
end
