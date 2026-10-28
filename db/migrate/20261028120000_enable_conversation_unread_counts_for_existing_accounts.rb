# O contador de conversas nao lidas no menu lateral depende desta feature. Ela
# passa a nascer ligada (config/features.yml); aqui liga nas contas que ja existem.
class EnableConversationUnreadCountsForExistingAccounts < ActiveRecord::Migration[7.0]
  def up
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!('conversation_unread_counts') }
    end
  end

  def down; end
end
