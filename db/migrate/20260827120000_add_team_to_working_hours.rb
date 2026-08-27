# Expediente passa a poder pertencer a uma Mesa, nao so a uma Inbox: um ticket
# aberto pelo Kanban nao tem Inbox nenhuma, e sem isso os SLAs do Ticket nao
# teriam como respeitar horario comercial. `inbox_id` ja era nulavel no banco -
# so o model exigia - entao nenhuma linha existente e afetada.
class AddTeamToWorkingHours < ActiveRecord::Migration[7.0]
  def change
    add_reference :working_hours, :team, null: true, index: true
  end
end
