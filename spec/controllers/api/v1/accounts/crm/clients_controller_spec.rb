require 'rails_helper'

RSpec.describe 'Crm clients API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:client_record) { create(:crm_client, account: account, representative_name: 'Representante Antigo') }

  def cabecalho
    admin.create_new_auth_token
  end

  def trocar_representante(body)
    patch "/api/v1/accounts/#{account.id}/crm/clients/#{client_record.id}/change_representative",
          params: { crm_client: body }, headers: cabecalho, as: :json
  end

  describe 'PATCH change_representative' do
    it 'atualiza so os dados do representante do cliente' do
      trocar_representante(representative_name: 'Representante Novo', representative_cpf: '999.999.999-99')

      expect(response).to have_http_status(:success)
      expect(client_record.reload.representative_name).to eq('Representante Novo')
      expect(client_record.representative_cpf).to eq('999.999.999-99')
    end

    it 'regenera todos os contratos ja gerados para o cliente' do
      template = create(:crm_contract_template, account: account)
      template.file.attach(
        io: File.open(build_minimal_docx('[[representante_nome]]')), filename: 'modelo.docx',
        content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
      contrato1 = create(:crm_generated_contract, account: account, template: template, client: client_record,
                                                  data: { 'representante_nome' => 'Representante Antigo' })
      contrato2 = create(:crm_generated_contract, account: account, template: template, client: client_record,
                                                  data: { 'representante_nome' => 'Representante Antigo' })
      [contrato1, contrato2].each do |contrato|
        contrato.pdf.attach(io: StringIO.new('pdf'), filename: 'a.pdf', content_type: 'application/pdf')
      end
      allow(Crm::Contracts::PdfConversion).to receive(:convert!) do |docx_path, _dir|
        pdf_path = docx_path.sub(/\.docx\z/, '.pdf')
        File.write(pdf_path, '%PDF fake')
        pdf_path
      end

      trocar_representante(representative_name: 'Representante Novo')

      expect(response).to have_http_status(:success)
      expect(contrato1.reload.data['representante_nome']).to eq('Representante Novo')
      expect(contrato2.reload.data['representante_nome']).to eq('Representante Novo')
      expect(contrato1.revisions.count).to eq(1)
      expect(response.parsed_body['results']).to contain_exactly(
        { 'id' => contrato1.id, 'status' => 'ok' }, { 'id' => contrato2.id, 'status' => 'ok' }
      )
    end

    # Um contrato que falha a conversao NAO pode travar a troca de
    # representante em si, nem impedir os outros contratos de atualizar.
    it 'continua a troca de representante mesmo se um contrato falhar ao regenerar' do
      template = create(:crm_contract_template, account: account)
      template.file.attach(
        io: File.open(build_minimal_docx('[[representante_nome]]')), filename: 'modelo.docx',
        content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
      contrato = create(:crm_generated_contract, account: account, template: template, client: client_record)
      contrato.pdf.attach(io: StringIO.new('pdf'), filename: 'a.pdf', content_type: 'application/pdf')
      allow(Crm::Contracts::PdfConversion).to receive(:convert!)
        .and_raise(Crm::Contracts::PdfConversion::ConversionError, 'LibreOffice fora do ar')

      trocar_representante(representative_name: 'Representante Novo')

      expect(response).to have_http_status(:success)
      expect(client_record.reload.representative_name).to eq('Representante Novo')
      expect(response.parsed_body['results']).to eq(
        [{ 'id' => contrato.id, 'status' => 'error', 'error' => 'LibreOffice fora do ar' }]
      )
    end
  end
end
