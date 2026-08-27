# Traduz o que acontece com o Ticket em operacoes de relogio.
#
# Toda regra de negocio dos tres SLAs esta aqui, e so aqui - o model dispara,
# este servico decide, o ClockService grava. Assim nao existe um "sistema" por
# tipo de SLA: e um so, com tres relogios.
class Tickets::Sla::ManagerService
  pattr_initialize [:ticket!]

  # Abertura: o prazo de atendimento e o de solucao comecam a contar da criacao,
  # e o estagio inicial ja e um estagio como qualquer outro.
  def ticket_opened
    clocks.start(:response)
    clocks.start(:resolution)
    clocks.start(:stage, ticket_column: ticket.ticket_column)
  end

  # Mover de coluna encerra o relogio anterior e abre um novo com a configuracao
  # da coluna de destino. Nao se reaproveita o prazo de solucao para isso.
  def stage_changed
    clocks.settle(:stage, meta: { reason: 'stage_changed' })
    clocks.start(:stage, ticket_column: ticket.ticket_column)
  end

  # Houve comunicacao valida com o cliente - pela aba do Ticket ou pelo Chat de
  # uma Conversation vinculada. So o primeiro relogio de atendimento em aberto e
  # cumprido; mensagens seguintes nao tem prazo correndo e nao geram evento.
  def customer_communicated(user:, source:, meta: {})
    clocks.fulfil(:response, user: user, source: source, meta: meta)
  end

  # Encerramento do Ticket - fechado, resolvido ou cancelado. Um ticket que
  # acabou nao corre mais contra prazo nenhum, entao os tres relogios param.
  #
  # O de atendimento normalmente ja esta cumprido, porque fechar exige
  # comunicacao com o cliente; ele so chega vivo aqui num fechamento
  # administrativo ou num cancelamento. Nesses casos vale a mesma regra dos
  # outros: dentro do prazo nao houve descumprimento, fora dele houve - e um
  # ticket cancelado no primeiro minuto nao deve acumular vencimento eterno.
  def ticket_terminated(at: Time.zone.now)
    %i[response stage resolution].each do |kind|
      clocks.settle(kind, at: at, meta: { reason: ticket.status })
    end
  end

  # Reabrir devolve o ticket ao quadro, entao ele volta a correr contra prazos.
  # Os relogios anteriores ficam intactos no historico - o que ja venceu venceu,
  # e o novo ciclo e contado do zero a partir de agora.
  def ticket_reopened
    clocks.start(:resolution)
    clocks.start(:stage, ticket_column: ticket.ticket_column)
  end

  # Mudar a prioridade muda o prazo prometido. Os relogios ainda em aberto sao
  # recalculados sobre a nova matriz, mantendo o inicio original: o cliente
  # espera desde a abertura, nao desde a reclassificacao. Relogios ja encerrados
  # nao mudam.
  def priority_changed
    %i[response resolution].each { |kind| restart_running(kind) }
  end

  private

  def clocks
    @clocks ||= Tickets::Sla::ClockService.new(ticket: ticket)
  end

  def restart_running(kind)
    running = ticket.ticket_applied_slas.running.find_by(kind: kind)
    return if running.blank?

    started_at = running.started_at
    clocks.start(kind, at: started_at)
  end
end
