require 'rails_helper'

# A tarefa que da a senha padrao aos solicitantes que ja existem. A regra que
# importa: quem JA tem acesso ao portal nunca e' alterado.
RSpec.describe 'client_access:apply_default_password' do
  subject(:rodar) do
    task = Rake::Task['client_access:apply_default_password']
    task.reenable
    task.invoke
  end

  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }
  let(:padrao) { 'Padrao#Forte-2026!' }

  # Os contatos nascem ANTES de a senha padrao existir no ambiente - senao a
  # propria criacao ja os provisionaria e o teste nao mediria a tarefa.
  let!(:elegivel) { create(:contact, account: account, email: 'novo@exemplo.com.br', company_id: empresa.id) }
  let!(:sem_empresa) { create(:contact, account: account, email: 'solto@exemplo.com.br') }
  let!(:com_acesso) do
    create(:contact, account: account, email: 'acesso@exemplo.com.br', company_id: empresa.id)
      .tap { |c| c.enable_client_access!(password: 'SenhaDoCliente@01') }
  end
  let!(:desligado) do
    create(:contact, account: account, email: 'desligado@exemplo.com.br', company_id: empresa.id)
      .tap { |c| c.enable_client_access!(password: 'OutraSenha@02') }
      .tap(&:disable_client_access!)
  end
  let!(:ja_entrou) do
    create(:contact, account: account, email: 'entrou@exemplo.com.br', company_id: empresa.id)
      .tap { |c| c.update_columns(client_last_sign_in_at: 2.days.ago) }
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD').and_return(padrao)
    allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD_EXPIRES_DAYS').and_return(nil)
  end

  context 'when running as a dry run' do
    before { allow(ENV).to receive(:[]).with('CONFIRM').and_return(nil) }

    it 'writes nothing' do
      expect { rodar }.to output(/Simulacao/).to_stdout
      expect(elegivel.reload.client_access_enabled).to be(false)
    end
  end

  context 'when confirmed' do
    before { allow(ENV).to receive(:[]).with('CONFIRM').and_return('1') }

    it 'gives the default password to an eligible contact' do
      expect { rodar }.to output(/aplicada/).to_stdout

      expect(elegivel.reload).to have_attributes(client_access_enabled: true, password_change_required: true)
      expect(elegivel.valid_password?(padrao)).to be(true)
    end

    it 'never touches a contact that already has access' do
      antes = com_acesso.reload.attributes.slice('encrypted_password', 'client_access_enabled', 'password_change_required')

      expect { rodar }.to output.to_stdout

      expect(com_acesso.reload.attributes.slice('encrypted_password', 'client_access_enabled', 'password_change_required'))
        .to eq(antes)
      expect(com_acesso.valid_password?('SenhaDoCliente@01')).to be(true)
    end

    it 'never touches a contact whose access was switched off' do
      expect { rodar }.to output.to_stdout

      expect(desligado.reload.valid_password?('OutraSenha@02')).to be(true)
      expect(desligado.client_access_enabled).to be(false)
    end

    it 'never touches a contact that already signed in once' do
      expect { rodar }.to output.to_stdout

      expect(ja_entrou.reload.client_access_enabled).to be(false)
      expect(ja_entrou.encrypted_password).to be_blank
    end

    it 'skips a contact without Empresa' do
      expect { rodar }.to output.to_stdout

      expect(sem_empresa.reload.client_access_enabled).to be(false)
    end
  end
end
