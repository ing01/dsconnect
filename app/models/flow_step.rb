# == Schema Information
#
# Table name: flow_steps
#
#  id                  :bigint           not null, primary key
#  content              :text
#  options              :jsonb            not null
#  position             :integer          default(0), not null
#  step_type            :integer          default("send_message"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  conversation_flow_id :bigint           not null
#  next_step_id         :bigint
#
# Indexes
#
#  index_flow_steps_on_account_id                        (account_id)
#  index_flow_steps_on_conversation_flow_id               (conversation_flow_id)
#  index_flow_steps_on_conversation_flow_id_and_position  (conversation_flow_id,position)
#  index_flow_steps_on_next_step_id                       (next_step_id)
#
class FlowStep < ApplicationRecord
  belongs_to :account
  belongs_to :conversation_flow
  belongs_to :next_step, class_name: 'FlowStep', optional: true

  enum step_type: {
    send_message: 0,
    ask_question: 1,
    present_options: 2,
    transfer_team: 3,
    transfer_queue: 4,
    add_label: 5,
    set_priority: 6,
    create_ticket: 7,
    end_flow: 8
  }

  # Steps whose execution requires a reply from the customer before the flow can advance.
  AWAITING_REPLY_TYPES = %w[ask_question present_options].freeze

  def self.reorder!(conversation_flow, step_ids)
    transaction do
      step_ids.each_with_index do |id, index|
        conversation_flow.flow_steps.where(id: id).update_all(position: index) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  validates :content, presence: true, if: -> { %w[send_message ask_question present_options].include?(step_type) }

  def awaiting_reply?
    step_type.in?(AWAITING_REPLY_TYPES)
  end

  def terminal?
    end_flow? || (next_step_id.blank? && !present_options?)
  end

  # For `present_options`, each item may carry its own `next_step_id` (branching);
  # every other step type falls back to the column-level `next_step_id` (linear path).
  def items
    return [] unless present_options?

    options.presence || []
  end
end
