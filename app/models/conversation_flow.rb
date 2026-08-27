# == Schema Information
#
# Table name: conversation_flows
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_conversation_flows_on_account_id           (account_id)
#  index_conversation_flows_on_account_id_and_name   (account_id,name) UNIQUE
#
class ConversationFlow < ApplicationRecord
  belongs_to :account
  has_many :flow_steps, -> { order(:position) }, dependent: :destroy
  has_many :agent_bots, dependent: :nullify
  has_many :conversation_flow_states, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }

  def first_step
    flow_steps.order(:position).first
  end
end
