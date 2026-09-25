# Horario de atendimento da conta (nao por Inbox/Mesa - ver OutOfOffisable
# pra isso): varios periodos por dia da semana, pra cobrir plantao de fim de
# semana com hora diferente do expediente normal. Sem indice unico em
# [account_id, day_of_week] de proposito - e o que permite mais de uma linha
# no mesmo dia.
class CreateAttendanceWindows < ActiveRecord::Migration[7.2]
  def change
    create_table :attendance_windows do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.integer :start_minute, null: false
      t.integer :end_minute, null: false

      t.timestamps
    end

    add_index :attendance_windows, %i[account_id day_of_week]
  end
end
