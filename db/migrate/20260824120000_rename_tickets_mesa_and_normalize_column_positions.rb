class RenameTicketsMesaAndNormalizeColumnPositions < ActiveRecord::Migration[7.2]
  def up
    rename_tickets_mesa
    normalize_positions
    add_index :ticket_columns, [:team_id, :position], name: 'index_ticket_columns_on_team_id_and_position'
  end

  def down
    remove_index :ticket_columns, name: 'index_ticket_columns_on_team_id_and_position'
  end

  private

  # 20260824090000 turned the old default "Tickets" board into a Team of the same
  # name. The product default Mesa is 'suporte', so rename that one Team and leave
  # every other Team alone.
  #
  # Goes through the model rather than raw SQL on purpose: the dashboard caches
  # the team list in IndexedDB and only revalidates once AccountCacheRevalidator
  # bumps the account's `team` cache key.
  def rename_tickets_mesa
    Team.where(name: 'tickets').find_each do |team|
      next if Team.exists?(account_id: team.account_id, name: 'suporte')

      team.update!(name: 'suporte')
    end
  end

  # Estagios backfilled by 20260824090000 all landed on position 0, leaving
  # `order(:position)` free to return them in any order on every request.
  def normalize_positions
    execute(<<~SQL.squish)
      UPDATE ticket_columns
      SET position = ordered.new_position
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY position, id) - 1 AS new_position
        FROM ticket_columns
      ) AS ordered
      WHERE ticket_columns.id = ordered.id
        AND ticket_columns.position <> ordered.new_position
    SQL
  end
end
