# Cor do badge, escolhida entre as mesmas 6 usadas em todo o resto do sistema
# (Label.vue / ticketLabels.js) - nao um seletor de cor livre, pra' nao ter
# card colorido diferente de tudo mais.
class AddColorToSuggestionPrioritiesAndCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :suggestion_priorities, :color, :string, null: false, default: 'slate'
    add_column :suggestion_categories, :color, :string, null: false, default: 'slate'
  end
end
