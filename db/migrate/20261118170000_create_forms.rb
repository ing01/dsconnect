# O Formulario (estilo Google Forms) - mesmo padrao de Checklist: um template
# por conta, com as perguntas guardadas em `fields` (jsonb), copiado pro
# ticket quando usado (ver TicketChecklistItem#form_id/form_response_id).
# `article_id` e opcional: qual Artigo da Central de Ajuda (POP) este
# formulario documenta, mostrado no proprio builder.
class CreateForms < ActiveRecord::Migration[7.2]
  def change
    create_table :forms do |t|
      t.references :account, null: false, foreign_key: true
      t.references :article, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'draft', null: false
      t.jsonb :fields, default: [], null: false
      t.jsonb :theme, default: {}, null: false

      t.timestamps
    end
  end
end
