# Acompanha uma importacao de tickets via CSV (Configuracoes > Tickets >
# Importar) - roda em segundo plano porque uma planilha real pode ter dezenas
# de milhares de linhas, tempo demais pra uma unica requisicao web aguentar.
# Ver Tickets::ImportJob (dispara o processamento) e Tickets::ImportService
# (mapeamento/criacao de verdade); a tela busca este registro periodicamente
# pra mostrar o progresso.
class TicketImport < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  has_one_attached :file

  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }

  scope :recent_first, -> { order(created_at: :desc) }

  def push_event_data
    {
      id: id,
      status: status,
      total_rows: total_rows,
      processed_rows: processed_rows,
      created_count: created_count,
      updated_count: updated_count,
      skipped_count: skipped_count,
      row_errors: row_errors,
      row_warnings: row_warnings,
      failure_message: failure_message,
      created_at: created_at.to_i,
      user_name: user&.name
    }
  end
end
