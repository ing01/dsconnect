# Enfileira a varredura de vencimentos por conta.
#
# So contas que de fato tenham relogio correndo entram na fila, para que uma
# instalacao sem Tickets nao pague nada por isso.
class Tickets::Sla::TriggerSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.where(id: TicketAppliedSla.running.select(:account_id)).find_each do |account|
      Tickets::Sla::SweepAccountJob.perform_later(account)
    end
  end
end
