# Uma alteracao em massa da Gestao de clientes e o que aconteceu com ela - ver
# `Companies::BulkUpdateJob`. `failures` guarda, no maximo, MAX_FAILURES clientes
# (id, nome e motivo); `failed_count` tem o total real.
class CompanyBulkUpdate < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze
  MAX_FAILURES = 200

  belongs_to :account
  belongs_to :user, optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def active?
    %w[queued running].include?(status)
  end

  def as_log
    {
      id: id, status: status, summary: summary, user_name: user&.name,
      total: total, processed_count: processed_count, updated_count: updated_count,
      failed_count: failed_count, failures: failures, error_message: error_message,
      created_at: created_at.to_i, finished_at: finished_at&.to_i
    }
  end
end
