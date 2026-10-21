require 'rails_helper'

RSpec.describe TicketApiKey do
  it 'generates a unique token on creation' do
    key = create(:ticket_api_key)
    expect(key.token).to be_present
  end

  it 'does not allow a second key for the same account' do
    account = create(:account)
    create(:ticket_api_key, account: account)

    expect { create(:ticket_api_key, account: account) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
