# Espelha o que a Inbox ja carrega, para que Sla::BusinessHoursService possa
# tratar Mesa e Inbox pela mesma interface.
class AddBusinessHoursToTeams < ActiveRecord::Migration[7.0]
  def change
    add_column :teams, :working_hours_enabled, :boolean, default: false, null: false
    add_column :teams, :timezone, :string, default: 'UTC', null: false
  end
end
