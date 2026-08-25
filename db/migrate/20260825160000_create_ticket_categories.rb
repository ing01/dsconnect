class CreateTicketCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_categories do |t|
      # Categories belong to a Mesa, exactly like Estagios do: "Erro" on the
      # Suporte desk has nothing to do with the Comercial desk's list.
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_categories, [:team_id, :name], unique: true
    add_index :ticket_categories, [:team_id, :position]

    # Category is mandatory on new tickets, so every Mesa that already exists
    # needs a usable list from the moment this ships - otherwise no ticket could
    # be opened until an admin went and created one by hand.
    reversible do |direction|
      direction.up { seed_default_categories }
    end
  end

  def seed_default_categories
    names = %w[Dúvida Erro Homologação Instalação Melhoria Treinamento]
    execute(<<~SQL.squish)
      INSERT INTO ticket_categories (team_id, name, position, created_at, updated_at)
      SELECT teams.id, category.name, category.position, NOW(), NOW()
      FROM teams
      CROSS JOIN (VALUES #{names.each_with_index.map { |name, index| "('#{name.gsub("'", "''")}', #{index})" }.join(', ')})
        AS category(name, position)
      ON CONFLICT (team_id, name) DO NOTHING
    SQL
  end
end
