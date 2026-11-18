require 'rails_helper'
require 'roo'

RSpec.describe 'Chat detail report', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Tonny Milan') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  before do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          assignee: administrator, status: :resolved)
  end

  def get_report(path = '', params = {}, user: administrator)
    get "/api/v1/accounts/#{account.id}/chat_detail_reports#{path}", params: params, headers: user.create_new_auth_token
  end

  describe 'GET index' do
    it 'returns the rows, the summary and the pagination' do
      get_report

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].size).to eq(1)
      expect(body['payload'].first['contact']).to eq('Tonny Milan')
      expect(body['summary']).to include('attended' => 1)
      expect(body['meta']).to include('count' => 1, 'page' => 1, 'per_page' => 25)
      expect(body['columns'].size).to eq(22)
      expect(body['summary_columns'].size).to eq(8)
    end

    it 'applies the filters' do
      get_report('', { status: 'open' })

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'is not available to an agent without report permission' do
      get_report('', {}, user: agent)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'asks to narrow the period when it is too big' do
      stub_const('ChatDetailReport::Builder::MAX_ROWS', 0)

      get_report

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to be_present
    end
  end

  describe 'GET export' do
    it 'writes the Excel with the two sheets of the model' do
      get_report('/export')

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

      path = Rails.root.join('tmp', "chat-spec-#{SecureRandom.hex(4)}.xlsx")
      File.binwrite(path, response.body)
      book = Roo::Excelx.new(path.to_s)
      FileUtils.rm_f(path)

      expect(book.sheets).to eq(['Chat Detalhado', 'Resumo'])
      expect(book.sheet('Chat Detalhado').row(1)).to eq(ChatDetailReport::Builder.headers)
      expect(book.sheet('Chat Detalhado').row(2)).to include('Tonny Milan')
      expect(book.sheet('Resumo').row(1)).to eq(ChatDetailReport::Builder::SUMMARY_COLUMNS.map(&:last))
      expect(book.sheet('Resumo').row(2).first).to eq(1)
    end
  end
end
