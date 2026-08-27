class AddQueueIdToConversations < ActiveRecord::Migration[7.2]
  def change
    add_reference :conversations, :queue, foreign_key: true, index: true
  end
end
