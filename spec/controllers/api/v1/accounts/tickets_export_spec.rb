require 'rails_helper'
require 'roo'

# A exportacao da Busca detalhada em Excel traz TODOS os dados; o PDF segue resumido.
RSpec.describe 'Tickets export', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { create(:ticket_category, team: team) }
  let!(:ticket) do
    create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category,
                    title: 'Erro na nota', observation: 'Observação do ticket')
  end

  def export(params = {})
    get "/api/v1/accounts/#{account.id}/tickets/export", params: params, headers: administrator.create_new_auth_token
  end

  def read_sheet
    path = Rails.root.join('tmp', "export-spec-#{SecureRandom.hex(4)}.xlsx")
    File.binwrite(path, response.body)
    sheet = Roo::Excelx.new(path.to_s)
    sheet.sheet(0)
    sheet
  ensure
    FileUtils.rm_f(path)
  end

  it 'writes the complete sheet: every column of the full export, with the ticket data' do
    export

    expect(response).to have_http_status(:success)
    sheet = read_sheet
    headers = sheet.row(1)
    expect(headers).to eq(Tickets::Export::FullSheet.headers)

    row = headers.zip(sheet.row(2)).to_h
    expect(row['Título']).to eq('Erro na nota')
    expect(row['Observação']).to eq('Observação do ticket')
    expect(row['Número']).to eq(ticket.display_id)
    # Nao preenchido: vazio.
    expect(row['Resolução']).to be_nil
    expect(row['Empresa']).to be_nil
  end

  it 'keeps the PDF as the short summary' do
    export(format_type: 'pdf')

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq('application/pdf')
  end
end
