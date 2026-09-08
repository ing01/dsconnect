# Uma etapa executada, registrada. E o historico que a automacao precisa ter:
# o que entrou, o que a etapa fez, o que deu e o erro quando houve.
#
# Gravado mesmo quando a etapa falha - principalmente quando falha, que e o caso
# em que alguem vai querer entender o que aconteceu.
class AutomationFlowRunEvent < ApplicationRecord
  belongs_to :account
  belongs_to :automation_flow_run

  enum outcome: { ok: 0, failed: 1, skipped: 2 }

  before_validation :ensure_account_id

  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  private

  def ensure_account_id
    self.account_id ||= automation_flow_run&.account_id
  end
end
