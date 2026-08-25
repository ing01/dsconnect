require 'rails_helper'

RSpec.describe TicketActivity do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'activity_type enum' do
    it {
      expect(subject).to define_enum_for(:activity_type).with_values(
        created: 0,
        status_changed: 1,
        column_changed: 2,
        priority_changed: 3,
        assignee_changed: 4,
        team_changed: 5,
        comment_added: 6,
        resolved: 7,
        reopened: 8,
        closed: 9,
        conversation_linked: 10,
        conversation_unlinked: 11,
        transferred: 12,
        parent_changed: 13,
        child_created: 14,
        merged_ticket: 15,
        merged_into: 16,
        duplicated: 17,
        sla_hours_added: 18,
        cancelled: 19,
        follower_added: 20,
        follower_removed: 21,
        title_changed: 22,
        company_changed: 23,
        contact_changed: 24
      )
    }
  end

  describe '#push_event_data' do
    it 'serializes with a nested user' do
      user = create(:user)
      activity = create(:ticket_activity, user: user, activity_type: :resolved)

      data = activity.push_event_data
      expect(data[:activity_type]).to eq('resolved')
      expect(data[:user]).to eq({ id: user.id, name: user.name })
    end

    it 'serializes a nil user as system-generated' do
      activity = create(:ticket_activity, user: nil)

      expect(activity.push_event_data[:user]).to be_nil
    end
  end
end
