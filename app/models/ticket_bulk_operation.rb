# Uma operacao em lote sobre tickets: o que foi pedido, por quem e o resultado
# de cada ticket (TicketBulkOperationItem).
class TicketBulkOperation < ApplicationRecord
  # Teto por operacao: o escolhido na tela (200) e o "todos do filtro" (500).
  SELECTION_LIMIT = 200
  FILTER_LIMIT = 500
  UNDO_WINDOW = 24.hours

  belongs_to :account
  belongs_to :user
  has_many :items, class_name: 'TicketBulkOperationItem', dependent: :destroy

  enum status: { pending: 'pending', running: 'running', completed: 'completed', failed: 'failed' }

  validates :action, inclusion: { in: ->(_) { Tickets::BulkOperations::Handlers::ACTIONS } }

  def undoable?
    completed? && undo_of_id.nil? && undone_at.nil? &&
      Tickets::BulkOperations::Handlers::REVERSIBLE.include?(action) &&
      finished_at.present? && finished_at > UNDO_WINDOW.ago
  end

  def push_event_data
    {
      id: id, action: action, status: status, total: total, succeeded: succeeded,
      skipped: skipped, failed: failed, undoable: undoable?, undone: undone_at.present?,
      user: { id: user_id, name: user&.name }, params: params.except('body', 'resolution'),
      started_at: started_at&.to_i, finished_at: finished_at&.to_i, created_at: created_at.to_i
    }
  end
end
