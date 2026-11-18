# Novo tipo de item de checklist ('form', em TicketChecklistItem::ITEM_TYPES):
# `form_id` e o Formulario a preencher; `form_response_id` so' e' gravado
# quando ja foi preenchido (e' o que marca o item como completo - ver
# TicketChecklistItem#sync_completed_from_value).
class AddFormToTicketChecklistItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :ticket_checklist_items, :form, foreign_key: true, index: true
    add_reference :ticket_checklist_items, :form_response, foreign_key: true, index: true
  end
end
