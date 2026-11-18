# Um preenchimento completo de um Formulario - o historico de respostas: quem preencheu,
# quando, e o que respondeu (em `form_answers`).
#
# `source` diz de onde veio: `ticket` (item de checklist do chamado), `internal` (agente, pelo
# artigo da Base de Conhecimento), `client` (cliente logado, pela Central de Ajuda) ou `public`
# (formulario aberto, sem login). Os tres ultimos podem nao ter chamado: a resposta fica so' guardada.
class FormResponse < ApplicationRecord
  belongs_to :account
  belongs_to :form
  SOURCES = %w[ticket internal client public].freeze

  belongs_to :ticket, optional: true
  belongs_to :contact, optional: true
  belongs_to :ticket_checklist_item, optional: true
  belongs_to :filled_by, class_name: 'User', optional: true

  has_many :form_answers, dependent: :destroy

  validates :source, inclusion: { in: SOURCES }

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
