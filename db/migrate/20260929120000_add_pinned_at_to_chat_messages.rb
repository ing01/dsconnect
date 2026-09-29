class AddPinnedAtToChatMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :chat_messages, :pinned_at, :datetime
  end
end
