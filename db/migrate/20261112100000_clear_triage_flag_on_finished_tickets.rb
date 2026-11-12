# Tickets cancelados, encerrados ou resolvidos que ficaram presos na fila de Triagem: a
# fila lista `pending_triage = true` sem olhar o status, e nem aprovar nem cancelar de
# novo resolve (cancelar um ticket ja cancelado nao faz nada). So desliga a marca nos
# que nao estao abertos; os abertos em triagem seguem na fila.
class ClearTriageFlagOnFinishedTickets < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE tickets
      SET pending_triage = FALSE,
          triaged_at = COALESCE(triaged_at, NOW())
      WHERE pending_triage = TRUE AND status <> 0
    SQL
  end

  def down
    # Dado corrigido: nao ha como saber quais estavam presos na fila.
  end
end
