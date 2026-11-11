# Fecha tickets parados no Estagio "Finalizado" (seja pelo `kind: completed` -
# a vaga obrigatoria de "concluido" que toda Mesa tem - seja por um Estagio
# chamado literalmente "Finalizado" criado a mao, comum em Mesas vindas de
# importacao) que ainda nao estao com status `closed`. E' o caso relatado
# pela Ingrid em 2026-11-11: tickets importados que ficaram no Estagio certo,
# mas com o status antigo (aberto) intacto.
#
# Fecha SEM as obrigatoriedades normais de fechamento (sem exigir Categoria,
# Catalogo de Servico, Resolucao ou comunicacao de encerramento ao cliente -
# ver Ticket#close! e TicketClosing#ensure_closeable!) - e' uma correcao
# administrativa de dados, nao um atendimento de verdade sendo encerrado.
#
# Por padrao so' LISTA o que seria fechado (dry run, nada e alterado). Passe
# CONFIRM=1 para executar de verdade. ACCOUNT_ID e opcional, para restringir a
# uma unica conta em vez da instancia inteira.
#
#   bundle exec rake duesoft:close_finalized_tickets
#   CONFIRM=1 bundle exec rake duesoft:close_finalized_tickets
#   CONFIRM=1 ACCOUNT_ID=3 bundle exec rake duesoft:close_finalized_tickets
namespace :duesoft do
  desc 'Fecha (sem obrigatoriedades) tickets presos no Estagio Finalizado com status diferente de encerrado'
  task close_finalized_tickets: :environment do
    confirm = ENV['CONFIRM'] == '1'
    account_id = ENV.fetch('ACCOUNT_ID', nil)

    scope = Ticket.joins(:ticket_column)
                  .where("ticket_columns.kind = 'completed' OR ticket_columns.name ILIKE ?", 'finalizado')
                  .where.not(status: %i[closed cancelled])
    scope = scope.where(account_id: account_id) if account_id.present?

    tickets = scope.includes(:team, :ticket_column).order(:account_id, :id).to_a

    if tickets.empty?
      puts 'Nenhum ticket parado no Estagio Finalizado com status aberto/resolvido. Nada a fazer.'
      next
    end

    puts "#{tickets.size} ticket(s) no Estagio Finalizado com status diferente de encerrado:"
    tickets.each do |ticket|
      puts "  conta ##{ticket.account_id} | ##{ticket.display_id} | mesa \"#{ticket.team.name}\" | " \
           "estagio \"#{ticket.ticket_column.name}\" | status atual: #{ticket.status}"
    end

    unless confirm
      puts
      puts "Nada foi alterado (modo somente leitura). Rode de novo com CONFIRM=1 para fechar " \
           "#{tickets.size} ticket(s) de verdade."
      next
    end

    closed = 0
    failed = []
    tickets.each do |ticket|
      ticket.close!(nil, skip_requirements: true)
      closed += 1
    rescue StandardError => e
      failed << "##{ticket.display_id}: #{e.message}"
    end

    puts
    puts "#{closed} ticket(s) fechado(s)."
    if failed.any?
      puts "#{failed.size} ticket(s) NAO fecharam:"
      failed.each { |msg| puts "  #{msg}" }
    end
  end
end
