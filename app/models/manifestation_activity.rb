# O historico de uma manifestacao. Mesmo formato do TicketActivity: tipo,
# antes/depois e `meta` para o que nao cabe em duas strings.
#
# Toda movimentacao grava QUEM e QUANDO - o `created_at` responde pelo quando, e
# o autor e o agente ou o contato, conforme o lado de onde a acao partiu.
class ManifestationActivity < ApplicationRecord
  belongs_to :manifestation
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  enum activity_type: {
    created: 0,
    status_changed: 1,
    assignee_changed: 2,
    replied: 3,
    internal_note_added: 4,
    converted_to_ticket: 5,
    client_replied: 6
  }

  before_validation :ensure_account_id

  scope :chronological, -> { order(:created_at, :id) }

  def author_name
    contact_id.present? ? contact&.name : user&.name
  end

  private

  def ensure_account_id
    self.account_id ||= manifestation&.account_id
  end
end
