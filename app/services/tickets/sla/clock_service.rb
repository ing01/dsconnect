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

  # Ajusta o prazo de um relogio, por horas ou por uma data e hora exata.
  #
  # Por horas, o prazo novo sai do prazo antigo e nao de agora: dar duas horas a
  # um prazo ja vencido nao pode virar duas horas a partir de hoje. Por data, o
  # valor informado e o prazo - inclusive para tras, quando alguem lancou um
  # prazo errado e precisa corrigir.
  #
  # Em ambos os casos o que a auditoria guarda e o mesmo: o prazo de antes, o de
  # depois, e a diferenca em horas com sinal.
  def adjust_deadline(kind, reason:, user: Current.user, hours: nil, due_at: nil)
    clock = current(kind)
    raise ActiveRecord::RecordNotFound, I18n.t('errors.ticket_sla.clock_not_found') if clock.blank?

    ticket.transaction do
      previous_due_at = clock.due_at
      new_due_at = target_due_at(previous_due_at, hours: hours, due_at: due_at)
      seconds = new_due_at - previous_due_at

      clock.update!(due_at: new_due_at, extended_seconds: clock.extended_seconds + seconds)
      revive(clock)
      record_extension(
        clock, previous_due_at,
        hours: seconds / 1.hour, reason: reason, user: user,
        mode: due_at.present? ? 'due_at' : 'hours'
      )
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
  # Uma das duas formas de dizer o prazo novo, nunca as duas ao mesmo tempo.
  def target_due_at(previous_due_at, hours:, due_at:)
    return due_at.in_time_zone if due_at.present?

    previous_due_at + hours.to_f.hours
  end

  def revive(clock)
    return unless clock.missed? && clock.completed_at.blank?

    clock.update!(status: :active)
  end

  # `adjustment` carrega o que descreve o ajuste - horas, motivo, quem fez e por
  # qual das duas formas -, mantendo a assinatura legivel conforme o registro
  # foi ganhando campos.
  def record_extension(clock, previous_due_at, adjustment)
    hours = adjustment[:hours]
    user = adjustment[:user]
    extension = ticket.ticket_sla_extensions.create!(
      account_id: ticket.account_id, user: user, hours: hours, reason: adjustment[:reason],
      ticket_applied_sla: clock, sla_kind: clock.kind,
      previous_due_at: previous_due_at, new_due_at: clock.due_at
    )
    log(clock, :extended, user: user,
                          meta: { hours: hours.to_f, reason: adjustment[:reason], previous_due_at: previous_due_at.iso8601 })
    ticket.log_sla_extension_activity(extension, user, adjustment[:mode])
    extension
  end

  def log(clock, event_type, user: nil, meta: {})
    TicketSlaEvent.create!(
      account_id: ticket.account_id, ticket: ticket, ticket_applied_sla: clock,
      user: user, event_type: event_type, meta: meta.compact
    )
  end
end
