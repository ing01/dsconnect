# O `tickets.due_at` era o unico prazo do ticket e virou o relogio de Solucao.
# Nenhuma data e descartada: cada ticket com prazo ganha um TicketAppliedSla de
# solucao, e as extensoes ja concedidas passam a apontar para ele.
#
# Modelos declarados aqui dentro de proposito: uma migracao precisa continuar
# rodando mesmo depois que os modelos da aplicacao mudarem de forma.
class MigrateTicketDueAtToResolutionSla < ActiveRecord::Migration[7.0]
  RESOLUTION_KIND = 2
  STATUS = { active: 0, hit: 1, missed: 2 }.freeze

  # rubocop:disable Style/OneClassPerFile
  class MigrationTicket < ApplicationRecord
    self.table_name = 'tickets'
  end

  class MigrationExtension < ApplicationRecord
    self.table_name = 'ticket_sla_extensions'
  end

  class MigrationAppliedSla < ApplicationRecord
    self.table_name = 'ticket_applied_slas'
  end
  # rubocop:enable Style/OneClassPerFile

  def up
    MigrationTicket.where.not(due_at: nil).find_each do |ticket|
      applied_sla = MigrationAppliedSla.create!(attributes_for(ticket))
      MigrationExtension.where(ticket_id: ticket.id)
                        .update_all(ticket_applied_sla_id: applied_sla.id, sla_kind: RESOLUTION_KIND) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # Reversivel: as extensoes voltam a apontar para nada e os relogios de solucao
  # gerados aqui somem. `tickets.due_at` nunca foi tocado.
  def down
    # rubocop:disable Rails/SkipsModelValidations
    MigrationExtension.where.not(ticket_applied_sla_id: nil).update_all(ticket_applied_sla_id: nil, sla_kind: nil)
    # rubocop:enable Rails/SkipsModelValidations
    MigrationAppliedSla.where(kind: RESOLUTION_KIND).delete_all
  end

  private

  def attributes_for(ticket)
    granted = granted_seconds(ticket)
    contracted = (ticket.due_at - ticket.created_at).to_i - granted
    completed_at = completion_time(ticket)

    {
      account_id: ticket.account_id, ticket_id: ticket.id,
      kind: RESOLUTION_KIND, threshold: [contracted, 0].max,
      only_during_business_hours: false,
      started_at: ticket.created_at, due_at: ticket.due_at,
      completed_at: completed_at, extended_seconds: granted,
      status: status_for(ticket, completed_at),
      created_at: ticket.created_at, updated_at: Time.zone.now
    }
  end

  def granted_seconds(ticket)
    hours = MigrationExtension.where(ticket_id: ticket.id).sum(:hours)
    (hours.to_f * 3600).to_i
  end

  # Um ticket cancelado tambem para o relogio - o prazo deixou de correr.
  def completion_time(ticket)
    ticket.closed_at || ticket.resolved_at || ticket.cancelled_at
  end

  def status_for(ticket, completed_at)
    return completed_at <= ticket.due_at ? STATUS[:hit] : STATUS[:missed] if completed_at.present?

    Time.zone.now <= ticket.due_at ? STATUS[:active] : STATUS[:missed]
  end
end
