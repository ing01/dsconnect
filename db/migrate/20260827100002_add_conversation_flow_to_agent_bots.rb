class AddConversationFlowToAgentBots < ActiveRecord::Migration[7.2]
  def change
    add_reference :agent_bots, :conversation_flow, foreign_key: true, index: true
  end
end
