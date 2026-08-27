# == Schema Information
#
# Table name: conversation_flow_states
#
#  id                    :bigint           not null, primary key
#  retry_count            :integer          default(0), not null
#  status                 :integer          default("in_progress"), not null
#  completed_at           :datetime
#  started_at             :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  conversation_flow_id   :bigint           not null
#  conversation_id        :bigint           not null
#  current_step_id        :bigint
#
# Indexes
#
#  index_conversation_flow_states_on_account_id            (account_id)
#  index_conversation_flow_states_on_conversation_flow_id  (conversation_flow_id)
#  index_conversation_flow_states_on_conversation_id       (conversation_id) UNIQUE
#  index_conversation_flow_states_on_current_step_id       (current_step_id)
#
class ConversationFlowState < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :conversation_flow
  belongs_to :current_step, class_name: 'FlowStep', optional: true

  enum status: { in_progress: 0, completed: 1, abandoned: 2 }

  validates :conversation_id, uniqueness: true
end
