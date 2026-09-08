require 'rails_helper'

RSpec.describe TicketTimeEntry do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:category).in_array(described_class::CATEGORIES) }
    it { is_expected.to validate_presence_of(:hours) }
    it { is_expected.to validate_numericality_of(:hours).is_greater_than(0) }
  end

  describe 'defaults' do
    it 'defaults worked_on to today and user to Current.user' do
      account = create(:account)
      ticket = create(:ticket, account: account)
      agent = create(:user, account: account)
      Current.user = agent

      entry = described_class.create!(account: account, ticket: ticket, category: 'implantacao', hours: 1.5)

      expect(entry.worked_on).to eq(Time.zone.today)
      expect(entry.user).to eq(agent)
    ensure
      Current.reset
    end
  end
end
