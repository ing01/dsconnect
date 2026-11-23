class CreateConversationPanelSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_panel_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      # Faixas pelo tempo que o cliente espera resposta (waiting_since):
      # verde ate `green_until_minutes`, laranja ate `orange_until_minutes`,
      # vermelho acima disso.
      t.integer :green_until_minutes, null: false, default: 5
      t.integer :orange_until_minutes, null: false, default: 15
      t.integer :refresh_seconds, null: false, default: 30
      # Quantas conversas cada card lista ao ser aberto.
      t.integer :list_limit, null: false, default: 50
      t.boolean :sound_enabled, null: false, default: false

      t.timestamps
    end
  end
end
