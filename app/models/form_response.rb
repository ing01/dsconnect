# Um preenchimento completo de um Formulario, sempre vinculado a um ticket -
# e o historico de respostas pedido: quem preencheu, quando, e o que
# respondeu (em `form_answers`).
class FormResponse < ApplicationRecord
  belongs_to :account
  belongs_to :form
  belongs_to :ticket
  belongs_to :ticket_checklist_item, optional: true
  belongs_to :filled_by, class_name: 'User', optional: true

  has_many :form_answers, dependent: :destroy

  scope :ordered, -> { order(created_at: :desc) }

  # So' existe quando o preenchimento veio de um item do checklist do ticket
  # (nao de uma resposta avulsa) - e' isso que marca o item como feito.
  def attach_to_checklist_item!
    return if ticket_checklist_item.blank?

    ticket_checklist_item.update!(
      form_response: self, completed: true, completed_at: Time.zone.now, completed_by: filled_by
    )
  end
end
