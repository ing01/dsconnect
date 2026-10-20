class CreateClientNotificationDismissals < ActiveRecord::Migration[7.1]
  def change
    # Os itens da aba Notificacoes do Portal sao sintetizados na hora
    # (TicketCustomerCommunication + mensagem de chat, ver
    # Api::V1::Client::NotificationsController) - nao existe uma tabela de
    # notificacao propria pro contato. Por isso o que persiste aqui nao e' o
    # item, so' a CHAVE dele (ex: "communication_42", "chat_17") que o contato
    # ja abriu ou removeu - a proxima listagem so' tira esses da conta.
    create_table :client_notification_dismissals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :item_key, null: false
      t.datetime :dismissed_at, null: false

      t.timestamps
    end

    add_index :client_notification_dismissals, [:contact_id, :item_key],
              unique: true, name: 'idx_client_notif_dismissals_on_contact_and_key'
  end
end
