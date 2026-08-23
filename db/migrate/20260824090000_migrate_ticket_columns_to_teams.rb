# Retires the standalone `TicketBoard` cadastro in favour of the "Mesa de
# Serviço" concept, which reuses the existing `Team` entity instead of a
# parallel one. `TicketColumn` (Estagio) now belongs directly to `Team`;
# `Ticket#team_id` becomes mandatory and always matches its column's team.
#
# Data migration (dev-only volume, this feature has not shipped yet): each
# existing TicketBoard is matched to (or turned into) a Team of the same
# name, its columns are re-pointed at that Team, and every ticket's
# `team_id` is force-synced from its column so the two can never disagree
# after this migration runs.
# rubocop:disable Style/OneClassPerFile -- throwaway, migration-scoped table shims
class MigrateTicketColumnsToTeams < ActiveRecord::Migration[7.2]
  class MigrationTicketBoard < ActiveRecord::Base
    self.table_name = 'ticket_boards'
  end

  class MigrationTicketColumn < ActiveRecord::Base
    self.table_name = 'ticket_columns'
  end

  class MigrationTeam < ActiveRecord::Base
    self.table_name = 'teams'
  end

  def up
    add_reference :ticket_columns, :team, foreign_key: true, index: true

    MigrationTicketBoard.reset_column_information
    MigrationTicketColumn.reset_column_information
    MigrationTeam.reset_column_information

    backfill_team_ids

    change_column_null :ticket_columns, :team_id, false
    remove_reference :ticket_columns, :ticket_board, index: true
    drop_table :ticket_boards

    execute <<~SQL.squish
      UPDATE tickets SET team_id = ticket_columns.team_id
      FROM ticket_columns
      WHERE tickets.ticket_column_id = ticket_columns.id
    SQL
    change_column_null :tickets, :team_id, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_team_ids
    MigrationTicketBoard.find_each do |board|
      team = team_for_board(board)
      MigrationTicketColumn.where(ticket_board_id: board.id).update_all(team_id: team.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def team_for_board(board)
    normalized_name = board.name.to_s.gsub(/[[:cntrl:]]/, '').strip.downcase
    MigrationTeam.find_by(account_id: board.account_id, name: normalized_name) ||
      MigrationTeam.create!(account_id: board.account_id, name: normalized_name, allow_auto_assign: true)
  end
end
# rubocop:enable Style/OneClassPerFile
