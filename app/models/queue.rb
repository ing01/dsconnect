# == Schema Information
#
# Table name: queues
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  description            :text
#  distribution_strategy  :integer          default("manual"), not null
#  name                   :string           not null
#  priority_boost         :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  default_sla_policy_id  :bigint
#  team_id                :bigint           not null
#
# Indexes
#
#  index_queues_on_account_id               (account_id)
#  index_queues_on_account_id_and_name       (account_id,name) UNIQUE
#  index_queues_on_default_sla_policy_id     (default_sla_policy_id)
#  index_queues_on_team_id                   (team_id)
#
class Queue < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :default_sla_policy, class_name: 'SlaPolicy', optional: true
  has_many :conversations, dependent: :nullify

  enum distribution_strategy: { manual: 0, round_robin: 1, least_busy: 2 }

  # Mirrors Conversation#priority - stored as the same integer values so a
  # queue's priority_boost can be assigned directly to conversation.priority.
  PRIORITY_BOOST_VALUES = { low: 0, medium: 1, high: 2, urgent: 3 }.freeze

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :priority_boost, inclusion: { in: PRIORITY_BOOST_VALUES.values }, allow_nil: true
  validate :team_belongs_to_account

  scope :active, -> { where(active: true) }

  def push_event_data
    {
      id: id,
      name: name,
      team_id: team_id,
      active: active,
      distribution_strategy: distribution_strategy
    }
  end

  # Applies this queue's defaults (default SLA, minimum priority) to a conversation
  # entering it. Never downgrades an SLA/priority the conversation already has.
  def apply_defaults_to(conversation)
    updates = {}
    updates[:sla_policy_id] = default_sla_policy_id if default_sla_policy_id.present? && conversation.sla_policy_id.blank?
    current_priority_value = conversation.priority.present? ? Conversation.priorities[conversation.priority] : nil
    updates[:priority] = priority_boost if priority_boost.present? && (current_priority_value.nil? || current_priority_value < priority_boost)
    conversation.assign_attributes(updates) if updates.present?
  end

  private

  def team_belongs_to_account
    return if team.blank?

    errors.add(:team, 'must belong to the same account') if team.account_id != account_id
  end
end
