# Marca como vencidos os relogios cujo prazo passou.
#
# O cumprimento e sempre por evento - uma mensagem enviada, uma coluna trocada,
# um ticket fechado. O vencimento nao tem evento proprio: ninguem faz nada e o
# prazo estoura sozinho, entao alguem precisa passar e constatar. E o mesmo
# desenho da varredura que ja existe para as Conversations
# (Sla::ProcessAccountAppliedSlasJob), no mesmo cron de 5 minutos.
class Tickets::Sla::SweepAccountJob < ApplicationJob
  queue_as :medium

  def perform(account)
    account.ticket_applied_slas.overdue.includes(:ticket).find_each do |clock|
      next unless clock.mark_missed!

      record_event(clock)
      dispatch(clock)
    end
  end

  private

  # Uma linha so quando o estado muda de fato: um ticket parado ha uma semana
  # gera um evento de vencimento, nao dois mil.
  def record_event(clock)
    TicketSlaEvent.create!(
      account_id: clock.account_id, ticket_id: clock.ticket_id,
      ticket_applied_sla: clock, event_type: :missed,
      meta: { detected_by: 'sweep', due_at: clock.due_at.iso8601 }
    )
  end

  # O evento alimenta o realtime hoje e e o gancho por onde as notificacoes de
  # vencimento entram depois, sem uma segunda engine de notificacao.
  def dispatch(clock)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::TICKET_SLA_MISSED, Time.zone.now, ticket: clock.ticket, applied_sla: clock
    )
  end
end
