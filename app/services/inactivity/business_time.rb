# Conta tempo so DENTRO do horario de atendimento da caixa de entrada
# (`working_hours`, no fuso da caixa), pros prazos da pausa por inatividade nao
# correrem de madrugada nem no fim de semana. Sem horario de atendimento ligado
# na caixa (ou com `enabled: false`), e' relogio corrido.
class Inactivity::BusinessTime
  MAX_DAYS = 60

  def initialize(inbox, enabled: true)
    @inbox = inbox
    @enabled = enabled && inbox.working_hours_enabled?
  end

  # Minutos de atendimento entre `from` e `to`.
  def elapsed_minutes(from, to = Time.current)
    return ((to - from) / 60.0) unless @enabled

    total = 0.0
    each_day(from, to) do |open_at, close_at|
      start = [open_at, from].max
      finish = [close_at, to].min
      total += (finish - start) / 60.0 if finish > start
    end
    total
  end

  def elapsed?(from, minutes)
    elapsed_minutes(from) >= minutes
  end

  # Instante em que `minutes` minutos de atendimento se completam, contando de `from`.
  def add_minutes(from, minutes)
    return from + minutes.minutes unless @enabled

    remaining = minutes.to_f
    day = from.in_time_zone(tz).to_date
    MAX_DAYS.times do
      window = window_for(day)
      if window
        start = [window.first, from].max
        available = (window.last - start) / 60.0
        return start + remaining.minutes if available.positive? && remaining <= available

        remaining -= available if available.positive?
      end
      day += 1
    end
    from + minutes.minutes
  end

  private

  def tz
    @inbox.timezone
  end

  def each_day(from, to)
    day = from.in_time_zone(tz).to_date
    last = to.in_time_zone(tz).to_date
    while day <= last
      window = window_for(day)
      yield(*window) if window
      day += 1
    end
  end

  # [abre, fecha] do dia no fuso da caixa, ou nil se fechado.
  def window_for(date)
    hour = hours_by_wday[date.wday]
    return if hour.nil? || hour.closed_all_day?

    zone = ActiveSupport::TimeZone[tz] || Time.zone
    [zone.local(date.year, date.month, date.day, hour.open_hour, hour.open_minutes),
     zone.local(date.year, date.month, date.day, hour.close_hour, hour.close_minutes)]
  end

  def hours_by_wday
    @hours_by_wday ||= @inbox.working_hours.index_by(&:day_of_week)
  end
end
