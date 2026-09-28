# Nem toda Mesa fala com cliente (ex: um time so de retaguarda/backoffice) nem
# toda Mesa executa Projetos - default true preserva o comportamento atual de
# quem ja existe (continua aparecendo em Conversas/Projetos ate alguem desmarcar).
class AddHandlesFlagsToTeams < ActiveRecord::Migration[7.2]
  def change
    add_column :teams, :handles_conversations, :boolean, default: true, null: false
    add_column :teams, :handles_projects, :boolean, default: true, null: false
  end
end
