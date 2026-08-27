# As operacoes elementares sobre um relogio: abrir, cumprir, encerrar, estender.
#
# Nao decide *quando* fazer nada - isso e do ManagerService. Aqui so se garante
# que cada operacao seja atomica, deixe evento de auditoria e nunca reescreva um
# relogio ja encerrado.
class Tickets::Sla::ClockService
  pattr_initialize [:ticket!]

  # Abre um relogio, encerrando antes o que estiver correndo do mesmo tipo - o
  # indice unico parcial no banco garante que so exista um ativo por tipo, entao
  # esquecer de encerrar aqui seria um erro de gravacao, nao um dado torto.
  #
  # Devolve nil quando nao ha prazo configurado: uma Mesa que nao promete prazo
  # para aquela prioridade, ou um Estagio sem vencimento, simplesmente nao tem
  # relogio - e diferente de ter um prazo de zero.
  def start(kind, ticket_column: nil, at: Time.zone.now)
    threshold, policy = threshold_for(kind, ticket_column)
    return if threshold.blank? || threshold.to_f <= 0

    ticket.transaction do
      settle_running(kind, at: at)
      create_clock(kind, threshold, policy, ticket_column, at)
    end
  end

  # O prazo foi atendido por alguem. Diferente de `settle`, que apenas constata
  # o resultado quando o relogio termina: aqui ha autor e origem, e e isso que a
  # auditoria do atendimento exige.
  def fulfil(kind, user:, source:, meta: {}, at: Time.zone.now)
    clock = running(kind)
    return if clock.blank?

    ticket.transaction do
      clock.settle!(at: at)
      log(clock, clock.hit? ? :hit : :missed, user: user, meta: meta.merge(source: source, fulfilled_at: at.iso8601))
    end
    clock
  end

  # Encerra o relogio constatando o resultado pelo proprio prazo.
  def settle(kind, at: Time.zone.now, meta: {})
    clock = running(kind)
    return if clock.blank?

    ticket.transaction do
      clock.settle!(at: at)
      log(clock, clock.hit? ? :hit : :missed, meta: meta)
    end
    clock
  end

  # Concede horas a um relogio especifico. O prazo novo sai do prazo antigo, nao
  # de agora: dar duas horas a um prazo ja vencido nao pode virar duas horas a
  # partir de hoje.
  def extend_deadline(kind, hours:, reason:, user: Current.user)
    clock = current(kind)
    raise ActiveRecord::RecordNotFound, I18n.t('errors.ticket_sla.clock_not_found') if clock.blank?

    seconds = hours.to_f.hours
    ticket.transaction do
      previous_due_at = clock.due_at
      clock.update!(due_at: previous_due_at + seconds, extended_seconds: clock.extended_seconds + seconds)
      revive(clock)
      record_extension(clock, hours, reason, user, previous_due_at)
    end
  end

  # O relogio que vale hoje para um tipo: o ativo, ou o ultimo encerrado.
  def current(kind)
    ticket.ticket_applied_slas.current_for(kind).first
  end

  private

  def running(kind)
    ticket.ticket_applied_slas.running.find_by(kind: kind)
  end

  def settle_running(kind, at:)
    clock = running(kind)
    return if clock.blank?

    clock.settle!(at: at)
    log(clock, clock.hit? ? :hit : :missed, meta: { reason: 'clock_replaced' })
  end

  def create_clock(kind, threshold, policy, ticket_column, at)
    business_hours = policy&.only_during_business_hours != false
    clock = ticket.ticket_applied_slas.create!(
      account_id: ticket.account_id, kind: kind, ticket_column: ticket_column,
      ticket_sla_policy: policy, threshold: threshold, only_during_business_hours: business_hours,
      started_at: at, due_at: deadline_for(threshold, business_hours, at)
    )
    log(clock, :started, meta: { ticket_column_id: ticket_column&.id })
    clock
  end

  def deadline_for(threshold, business_hours, at)
    Tickets::Sla::DeadlineCalculator.new(
      team: ticket.team, start_time: at, threshold_seconds: threshold,
      only_during_business_hours: business_hours
    ).deadline
  end

  # O prazo do estagio pertence ao proprio estagio; os outros dois vem da matriz
  # Mesa x Prioridade.
  def threshold_for(kind, ticket_column)
    return [ticket_column&.stage_threshold, nil] if kind.to_s == 'stage'

    policy = ticket.ticket_sla_policy
    [policy&.threshold_for(kind), policy]
  end

  # Estender um prazo vencido devolve o relogio a corrida - foi exatamente por
  # isso que as horas foram concedidas. Um relogio ja cumprido nao volta.
  def revive(clock)
    return unless clock.missed? && clock.completed_at.blank?

    clock.update!(status: :active)
  end

  def record_extension(clock, hours, reason, user, previous_due_at)
    extension = ticket.ticket_sla_extensions.create!(
      account_id: ticket.account_id, user: user, hours: hours, reason: reason,
      ticket_applied_sla: clock, sla_kind: clock.kind,
      previous_due_at: previous_due_at, new_due_at: clock.due_at
    )
    log(clock, :extended, user: user, meta: { hours: hours.to_f, reason: reason, previous_due_at: previous_due_at.iso8601 })
    ticket.log_sla_extension_activity(extension, user)
    extension
  end

  def log(clock, event_type, user: nil, meta: {})
    TicketSlaEvent.create!(
      account_id: ticket.account_id, ticket: ticket, ticket_applied_sla: clock,
      user: user, event_type: event_type, meta: meta.compact
    )
  end
end
