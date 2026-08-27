# Converte um prazo em segundos numa data de vencimento para um Ticket.
#
# Nao reimplementa calendario: delega a Sla::BusinessHoursService, o mesmo
# servico que os SLAs das Conversations usam, passando a Mesa no lugar da Inbox.
# A Mesa responde a `working_hours`, `working_hours_enabled?` e `timezone`
# exatamente como uma Inbox, que e tudo de que aquele servico precisa.
class Tickets::Sla::DeadlineCalculator
  pattr_initialize [:team!, :start_time!, :threshold_seconds!, { only_during_business_hours: true }]

  def deadline
    return start_time + threshold_seconds.to_i.seconds unless only_during_business_hours

    Sla::BusinessHoursService.new(
      schedulable: team,
      start_time: start_time,
      threshold_seconds: threshold_seconds,
      working_hours_by_day_cache: working_hours_by_day_cache
    ).deadline
  end

  private

  # Uma Mesa sem expediente cadastrado cai no caminho de horas corridas dentro do
  # proprio BusinessHoursService; o cache evita reconsultar as sete linhas.
  def working_hours_by_day_cache
    @working_hours_by_day_cache ||= team.working_hours.index_by(&:day_of_week)
  end
end
