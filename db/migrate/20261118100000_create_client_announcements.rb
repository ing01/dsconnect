class CreateClientAnnouncements < ActiveRecord::Migration[7.0]
  def change
    create_table :client_announcements do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      # info | warning | success | urgent - define cor e icone no Portal.
      t.string :kind, null: false, default: 'info'
      # Janela de exibicao: dentro dela o aviso abre em modal a cada login.
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :link_url
      t.string :link_label
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      # Publico: 'all' (toda a conta) ou 'segmented'. Na segmentacao, cada lista
      # vazia = sem filtro naquela dimensao; entre dimensoes e' E, dentro da
      # dimensao e' OU. O contato ve o aviso se QUALQUER empresa dele combina.
      t.string :audience, null: false, default: 'all'
      t.bigint :company_ids, array: true, null: false, default: []
      t.bigint :company_niche_ids, array: true, null: false, default: []
      t.bigint :company_sub_niche_ids, array: true, null: false, default: []
      t.integer :client_levels, array: true, null: false, default: []
      t.references :created_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :client_announcements, [:account_id, :active, :starts_at, :ends_at],
              name: 'index_client_announcements_on_account_window'
  end
end
