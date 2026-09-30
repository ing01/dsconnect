# A inscricao de push (VAPID) de um Contato do Portal - separada de
# `notification_subscriptions` porque aquela e' `belongs_to :user` (uso
# interno); aqui quem assina e' um Contact, sem sessao de usuario nenhuma.
class CreateClientPushSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :client_push_subscriptions do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.jsonb :subscription_attributes, null: false, default: {}

      t.timestamps
    end

    add_index :client_push_subscriptions, :account_id
    add_index :client_push_subscriptions, :contact_id
  end
end
