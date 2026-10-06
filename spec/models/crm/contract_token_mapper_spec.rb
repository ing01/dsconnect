require 'rails_helper'

RSpec.describe Crm::ContractTokenMapper do
  let(:account) { create(:account) }
  let(:client) do
    create(:crm_client, account: account, name: 'Duesoft Sistemas', cnpj: '00.000.000/0001-00',
                        trade_name: 'Duesoft', email: 'contato@duesoft.com.br', phone: '(11) 4000-0000')
  end

  describe '.LOCKED_CLIENT_TOKEN_KEYS' do
    it 'tem exatamente os 5 tokens de identidade do cliente' do
      expect(described_class::LOCKED_CLIENT_TOKEN_KEYS).to contain_exactly(
        'cliente_razao_social', 'cliente_cnpj', 'cliente_nome_fantasia', 'cliente_email', 'cliente_telefone'
      )
    end
  end

  describe '#to_h' do
    it 'preenche os tokens travados a partir do cadastro' do
      tokens = described_class.new(client: client).to_h

      expect(tokens['cliente_razao_social']).to eq('Duesoft Sistemas')
      expect(tokens['cliente_cnpj']).to eq('00.000.000/0001-00')
      expect(tokens['cliente_nome_fantasia']).to eq('Duesoft')
      expect(tokens['cliente_email']).to eq('contato@duesoft.com.br')
      expect(tokens['cliente_telefone']).to eq('(11) 4000-0000')
    end

    it 'inclui os tokens do representante' do
      client.update!(representative_name: 'Fulano', representative_cpf: '123.456.789-00')

      tokens = described_class.new(client: client).to_h

      expect(tokens['representante_nome']).to eq('Fulano')
      expect(tokens['representante_cpf']).to eq('123.456.789-00')
    end
  end
end
