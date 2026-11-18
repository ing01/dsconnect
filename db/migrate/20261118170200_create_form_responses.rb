# Um preenchimento completo de um Formulario, sempre vinculado a um ticket
# (pedido explicito: historico de respostas por chamado). `ticket_checklist_item_id`
# e opcional - presente quando o preenchimento veio de um item do checklist
# do ticket (ver TicketChecklistItem#form_response_id).
class CreateFormResponses < ActiveRecord::Migration[7.2]
  def change
    create_table :form_responses do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.references :ticket_checklist_item, foreign_key: true
      t.references :filled_by, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
