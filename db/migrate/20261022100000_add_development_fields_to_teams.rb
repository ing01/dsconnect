# O "Modulo de Desenvolvimento" (Backlog + Sprints) dentro da aba de Tickets -
# ativado por Mesa, nunca por nome fixo em codigo. Mesma forma dos flags que
# ja existem (handles_conversations, handles_projects, visible_in_portal).
class AddDevelopmentFieldsToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :development_module_enabled, :boolean, null: false, default: false
    add_reference :teams, :default_checklist, foreign_key: { to_table: :checklists }
  end
end
