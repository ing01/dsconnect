class Api::V1::Accounts::CalendarEventsController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_event, only: [:show, :update, :destroy]
  before_action :check_authorization

  # Scoped by Mesa (the calendar page) or by Ticket (the Compromissos tab).
  # One of the two is required so the endpoint can never dump the whole account.
  def index
    raise ActionController::ParameterMissing, :team_id if params[:team_id].blank? && params[:ticket_id].blank?

    scope = Current.account.calendar_events
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = filter_by_ticket(scope)

    @calendar_events = windowed?(params) ? expand_for_window(scope) : scope.includes(:attendees, :tickets, :created_by).order(:start_at)
  end

  def show; end

  def create
    @calendar_event = Current.account.calendar_events.new(calendar_event_params)
    @calendar_event.created_by = Current.user
    @calendar_event.save!
  end

  def update
    if params[:scope].present? && @calendar_event.recurring?
      @calendar_event = CalendarEvents::UpdateOccurrenceService.new(
        calendar_event: @calendar_event, scope: params[:scope], occurrence_date: parsed_date(params[:occurrence_date])&.to_date,
        attributes: calendar_event_params
      ).perform
    else
      @calendar_event.update!(calendar_event_params)
    end
  end

  def destroy
    if params[:scope].present? && @calendar_event.recurring?
      CalendarEvents::DestroyOccurrenceService.new(
        calendar_event: @calendar_event, scope: params[:scope], occurrence_date: parsed_date(params[:occurrence_date])&.to_date
      ).perform
    else
      @calendar_event.destroy!
    end
    head :ok
  end

  private

  def windowed?(params)
    parsed_date(params[:since]) && parsed_date(params[:until])
  end

  # A janela so' filtra por `overlapping` (start_at/end_at da PROPRIA linha)
  # os eventos simples - uma serie recorrente pode ter nascido muito antes da
  # janela e ainda gerar ocorrencias dentro dela, entao toda serie que ainda
  # nao tenha COMECADO depois do fim da janela entra no escopo, e e' o
  # `OccurrenceExpansionService` quem decide, data a data, o que cai dentro.
  def expand_for_window(scope)
    since_at = parsed_date(params[:since])
    until_at = parsed_date(params[:until])

    windowed_scope = scope.where(recurrence_frequency: :single).overlapping(since_at, until_at)
                          .or(scope.series.where(start_at: ..until_at))

    CalendarEvents::OccurrenceExpansionService.new(scope: windowed_scope, since: since_at, until_at: until_at)
                                              .perform.sort_by(&:start_at)
  end

  def filter_by_ticket(scope)
    return scope if params[:ticket_id].blank?

    scope.joins(:calendar_event_tickets).where(calendar_event_tickets: { ticket_id: params[:ticket_id] })
  end

  def check_authorization(model = nil)
    super(model || @calendar_event || CalendarEvent)
  end

  def fetch_calendar_event
    @calendar_event = Current.account.calendar_events.find(params[:id])
  end

  def parsed_date(value)
    Time.zone.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def calendar_event_params
    params.require(:calendar_event).permit(
      :title, :description, :start_at, :end_at, :all_day, :location, :color, :team_id, :event_type,
      :recurrence_frequency, :recurrence_interval, :recurrence_end_at, :recurrence_count,
      :reminder_minutes_before,
      attendee_ids: [], ticket_ids: []
    )
  end
end
