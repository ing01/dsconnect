class Api::V1::Accounts::CalendarEventsController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_event, only: [:show, :update, :destroy]
  before_action :check_authorization

  # Scoped by Mesa (the calendar page) or by Ticket (the Compromissos tab).
  # One of the two is required so the endpoint can never dump the whole account.
  def index
    raise ActionController::ParameterMissing, :team_id if params[:team_id].blank? && params[:ticket_id].blank?

    scope = Current.account.calendar_events.includes(:attendees, :tickets, :created_by)
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = filter_by_ticket(scope)
    @calendar_events = filter_by_window(scope).order(:start_at)
  end

  def show; end

  def create
    @calendar_event = Current.account.calendar_events.new(calendar_event_params)
    @calendar_event.created_by = Current.user
    @calendar_event.save!
  end

  def update
    @calendar_event.update!(calendar_event_params)
  end

  def destroy
    @calendar_event.destroy!
    head :ok
  end

  private

  def filter_by_window(scope)
    since_at = parsed_date(params[:since])
    until_at = parsed_date(params[:until])
    return scope unless since_at && until_at

    scope.overlapping(since_at, until_at)
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
      :title, :description, :start_at, :end_at, :all_day, :location, :color, :team_id,
      attendee_ids: [], ticket_ids: []
    )
  end
end
