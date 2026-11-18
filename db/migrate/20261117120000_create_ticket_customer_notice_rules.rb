class CreateTicketCustomerNoticeRules < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_customer_notice_rules do |t|
      t.references :account, null: false, foreign_key: true
      # 'stage': o ticket entrou no Estagio `ticket_column_id`.
      # 'team': o ticket passou para a Mesa `team_id` (opcionalmente vindo de `from_team_id`).
      t.string :kind, null: false
      t.string :name, null: false
      t.references :ticket_column, foreign_key: { on_delete: :cascade }
      t.references :team, foreign_key: { on_delete: :cascade }
      t.bigint :from_team_id
      t.text :body, null: false
      t.boolean :notify_customer, null: false, default: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :ticket_customer_notice_rules, %i[account_id kind active],
              name: 'index_ticket_notice_rules_on_account_kind_active'
    add_foreign_key :ticket_customer_notice_rules, :teams, column: :from_team_id, on_delete: :cascade
  end
end
