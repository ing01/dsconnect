require 'rails_helper'

# Anexos de tickets filhos criados quando a copia de arquivos ainda falhava: o registro
# existe, o arquivo nao. A tarefa devolve o arquivo a partir do pai.
RSpec.describe 'duesoft:repair_child_ticket_attachments' do
  subject(:rodar) do
    task = Rake::Task['duesoft:repair_child_ticket_attachments']
    task.reenable
    task.invoke
  end

  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) { team.ticket_columns.first }
  let(:parent) { create(:ticket, account: account, ticket_column: column, team: team) }
  let(:child) { create(:ticket, account: account, ticket_column: column, team: team, parent: parent) }
  let!(:origin) { create(:ticket_attachment, ticket: parent) }
  let!(:broken) do
    copy = create(:ticket_attachment, ticket: child)
    # Simula o defeito: o registro e o blob existem, o arquivo no storage nao.
    copy.file.blob.update!(checksum: origin.file.blob.checksum)
    copy.file.blob.service.delete(copy.file.blob.key)
    copy
  end

  before { allow($stdout).to receive(:puts) }

  after { ENV.delete('CONFIRM') }

  it 'por padrao so lista: nada e alterado' do
    rodar

    expect(broken.file.blob.service.exist?(broken.file.blob.key)).to be(false)
  end

  it 'com CONFIRM=1 devolve o arquivo que faltava, com o mesmo conteudo do pai' do
    ENV['CONFIRM'] = '1'

    rodar

    expect(broken.file.blob.service.exist?(broken.file.blob.key)).to be(true)
    expect(broken.reload.file.download).to eq(origin.file.download)
  end

  it 'nao mexe em anexo cujo arquivo esta inteiro' do
    ENV['CONFIRM'] = '1'
    healthy = create(:ticket_attachment, ticket: child)
    checksum = healthy.file.blob.checksum

    rodar

    expect(healthy.reload.file.blob.checksum).to eq(checksum)
    expect(healthy.file.blob.service.exist?(healthy.file.blob.key)).to be(true)
  end
end
