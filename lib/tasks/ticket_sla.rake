# Liga os tres SLAs nos tickets que ja estavam abertos antes de a Mesa ter
# prazos configurados.
#
# Os relogios so comecam sozinhos na abertura, na reabertura ou numa mudanca de
# estagio. Sem esta tarefa, um ticket aberto ontem ficaria para sempre sem SLA
# depois que a matriz da Mesa fosse preenchida hoje.
#
# Os prazos sao contados de quando a demanda realmente entrou - a criacao do
# ticket, e a entrada no estagio atual - e nao de agora, para que o backfill nao
# perdoe atrasos que ja aconteceram. Como o `due_at` e calculado pelo mesmo
# servico de expediente, a varredura seguinte marca como vencido o que ja estava.
#
#   bundle exec rake duesoft:sla_backfill              # todas as contas
#   bundle exec rake duesoft:sla_backfill ACCOUNT_ID=1
#   bundle exec rake duesoft:sla_backfill DRY_RUN=1    # so relata
namespace :duesoft do
  desc 'Inicia os relogios de SLA dos tickets abertos que ainda nao os tem'
  task sla_backfill: :environment do
    dry_run = ENV['DRY_RUN'].present?
    scope = Ticket.operational.where.missing(:ticket_applied_slas)
    scope = scope.where(account_id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?

    puts "Tickets abertos sem SLA: #{scope.count}#{' (DRY_RUN)' if dry_run}"
    started = 0

    scope.includes(:team, :ticket_column).find_each do |ticket|
      clocks = describe_clocks(ticket)
      if clocks.empty?
        puts "  ##{ticket.display_id} sem prazo configurado para a Mesa/prioridade - ignorado"
        next
      end

      puts "  ##{ticket.display_id} #{clocks.join(', ')}"
      next if dry_run

      start_clocks(ticket)
      started += 1
    end

    puts(dry_run ? 'Nada gravado.' : "Relogios iniciados em #{started} ticket(s).")
  end
end

# Quais relogios este ticket ganharia, para que o DRY_RUN diga algo util.
def describe_clocks(ticket)
  policy = ticket.ticket_sla_policy
  kinds = []
  kinds << 'atendimento' if policy&.response_threshold.present?
  kinds << 'solucao' if policy&.resolution_threshold.present?
  kinds << 'estagio' if ticket.ticket_column&.stage_threshold.present?
  kinds
end

def start_clocks(ticket)
  service = Tickets::Sla::ClockService.new(ticket: ticket)
  service.start(:response, at: ticket.created_at)
  service.start(:resolution, at: ticket.created_at)
  service.start(:stage, ticket_column: ticket.ticket_column, at: stage_entered_at(ticket))
end

# Quando o ticket entrou no estagio em que esta: a ultima mudanca de coluna
# registrada no historico, ou a criacao, se ele nunca saiu de onde nasceu.
def stage_entered_at(ticket)
  ticket.ticket_activities
        .where(activity_type: :column_changed)
        .maximum(:created_at) || ticket.created_at
end
