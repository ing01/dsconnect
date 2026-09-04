class AddKindToTicketColumns < ActiveRecord::Migration[7.2]
  class MigrationTicketColumn < ActiveRecord::Base
    self.table_name = 'ticket_columns'
  end

  class MigrationTeam < ActiveRecord::Base
    self.table_name = 'teams'
  end

  def up
    add_column :ticket_columns, :kind, :string, default: 'normal', null: false
    add_index :ticket_columns, [:team_id, :kind], unique: true, where: "kind != 'normal'",
                                                   name: 'index_ticket_columns_on_team_id_and_kind_unique'

    backfill_required_columns!
  end

  def down
    remove_index :ticket_columns, name: 'index_ticket_columns_on_team_id_and_kind_unique'
    remove_column :ticket_columns, :kind
  end

  private

  # Every Mesa gets a mandatory Pendente/Finalizado pair if it does not
  # already have one, so existing Mesas (created before this migration)
  # keep working with the new "coluna Pendente obrigatoria" / "Finalizado
  # oculto" behaviour without manual setup.
  def backfill_required_columns!
    MigrationTeam.find_each do |team|
      columns = MigrationTicketColumn.where(team_id: team.id).order(:position, :id)

      unless columns.exists?(kind: 'pending')
        min_position = columns.minimum(:position) || 0
        MigrationTicketColumn.create!(team_id: team.id, name: 'Pendente', kind: 'pending', position: min_position - 1)
      end

      next if columns.exists?(kind: 'completed')

      max_position = columns.maximum(:position) || 0
      MigrationTicketColumn.create!(team_id: team.id, name: 'Finalizado', kind: 'completed', position: max_position + 1)
    end
  end
end
