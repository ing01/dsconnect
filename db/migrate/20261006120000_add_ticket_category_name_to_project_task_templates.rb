# Categoria padrao da tarefa do modulo de projeto. Guardada pelo NOME, e nao
# pelo id: a mesma Categoria existe em cada Mesa (com o mesmo nome), e o projeto
# escolhe a Mesa so' na hora de criar - a categoria certa e' achada pelo nome
# dentro da Mesa escolhida.
class AddTicketCategoryNameToProjectTaskTemplates < ActiveRecord::Migration[7.2]
  def change
    add_column :project_task_templates, :ticket_category_name, :string
  end
end
