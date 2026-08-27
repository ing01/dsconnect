# Mesas que ja existiam nasceram antes de a Mesa ter expediente, entao nao tem a
# semana padrao que OutOfOffisable cria no `after_create`. Sem estas linhas, uma
# Mesa antiga com expediente ligado calcularia prazo como se fosse fechada todos
# os dias.
#
# `working_hours_enabled` continua false: isto so preenche a semana, nao muda o
# comportamento de ninguem ate um administrador ligar o expediente.
class BackfillTeamWorkingHours < ActiveRecord::Migration[7.0]
  def up
    Team.reset_column_information
    Team.where.missing(:working_hours).find_each do |team|
      OutOfOffisable::DEFAULT_WORKING_HOURS.each { |attributes| team.working_hours.create!(attributes) }
    end
  end

  def down
    WorkingHour.where.not(team_id: nil).delete_all
  end
end
