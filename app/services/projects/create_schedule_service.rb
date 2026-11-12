# Botao "Criar cronograma" no detalhe do Projeto (pedido da Ingrid,
# 2026-11-12): um lote de agendamentos, cada um com ticket (existente OU
# criado na hora) + data/hora + responsavel. Ao salvar, cada linha:
#   1. garante o ticket (cria um simples se nao veio `ticket_id`),
#   2. grava `scheduled_at` nele e, se um responsavel foi escolhido/trocado,
#      atualiza o `assignee`,
#   3. cria um CalendarEvent (agenda da Mesa do projeto) ja' vinculado ao
#      ticket e com o responsavel como attendee - mesmo mecanismo que
#      TicketAppointmentsTab.vue ja' usa por ticket, so' que em lote aqui.
module Projects
  class CreateScheduleService
    pattr_initialize [:account!, :project!, :user!, :items]

    Result = Struct.new(:ticket, :calendar_event, keyword_init: true)

    def perform
      return [] if items.blank?

      ActiveRecord::Base.transaction do
        items.map { |item_data| process(item_data.with_indifferent_access) }
      end
    end

    private

    def process(item)
      ticket = ticket_for(item)

      responsible_id = item[:responsible_user_id].presence || ticket.assignee_id
      responsible_id = nil unless responsible_id.present? && project.team.members.exists?(id: responsible_id)

      ticket.update!(
        scheduled_at: start_at(item),
        assignee_id: responsible_id || ticket.assignee_id
      )

      calendar_event = account.calendar_events.create!(
        title: item[:title].presence || ticket.title,
        description: item[:description],
        start_at: start_at(item),
        end_at: end_at(item),
        team_id: project.team_id,
        event_type: :event,
        created_by: user,
        ticket_ids: [ticket.id],
        attendee_ids: responsible_id ? [responsible_id] : []
      )

      Result.new(ticket: ticket, calendar_event: calendar_event)
    end

    def ticket_for(item)
      return project.tickets.find(item[:ticket_id]) if item[:ticket_id].present?

      create_ticket(item)
    end

    def create_ticket(item)
      account.tickets.create!(
        team: project.team,
        ticket_column: target_column,
        ticket_category: default_ticket_category,
        company: project.company,
        contact: project.contact,
        project: project,
        title: item[:new_ticket_title].presence || item[:title],
        priority: :medium
      )
    end

    def target_column
      project.team.ticket_columns.find_by(kind: 'pending') || project.team.ticket_columns.order(:position).first
    end

    def default_ticket_category
      project.team.ticket_categories.find_by(id: project.default_ticket_category_id) ||
        project.team.ticket_categories.order(:position, :id).first
    end

    def start_at(item)
      parse_datetime(item[:start_at])
    end

    def end_at(item)
      parse_datetime(item[:end_at]) || start_at(item)&.+(1.hour)
    end

    def parse_datetime(val)
      return nil if val.blank?
      return val if val.is_a?(Time) || val.is_a?(DateTime)

      Time.zone.parse(val.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
