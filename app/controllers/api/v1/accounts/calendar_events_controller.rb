class Api::V1::Accounts::CalendarEventsController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_event, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    scope = Current.account.calendar_events.where(team_id: params.require(:team_id)).includes(:attendees, :tickets, :created_by)
    since_at = parsed_date(params[:since])
    until_at = parsed_date(params[:until])
    scope = scope.overlapping(since_at, until_at) if since_at && until_at
    @calendar_events = scope.order(:start_at)
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
