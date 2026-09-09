class ChangeCompanyClientLevelToFivePointScale < ActiveRecord::Migration[7.2]
  def up
    # Shift the old 0-3 enum (low/medium/high/vip) into the new 1-5 scale,
    # keeping relative order; 5 becomes newly reachable as "max priority".
    execute 'UPDATE companies SET client_level = client_level + 1'
    change_column_default :companies, :client_level, from: 0, to: 1
  end

  def down
    change_column_default :companies, :client_level, from: 1, to: 0
    execute 'UPDATE companies SET client_level = client_level - 1'
  end
end
