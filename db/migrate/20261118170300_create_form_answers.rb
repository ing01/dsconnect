# Uma resposta por pergunta dentro de um FormResponse. `field_id` e o id local
# (string) dentro do `fields` jsonb do Form - nao e FK de verdade, o mesmo
# jeito que TicketChecklistItem nao tem um FK pro item de dentro de
# Checklist#items. `value` guarda string/array de string/data conforme o
# tipo do campo; o tipo file_upload usa o anexo (ver FormAnswer#file).
class CreateFormAnswers < ActiveRecord::Migration[7.2]
  def change
    create_table :form_answers do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form_response, null: false, foreign_key: true
      t.string :field_id, null: false
      t.jsonb :value

      t.timestamps
    end
  end
end
