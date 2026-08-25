class Api::V1::Accounts::TicketFollowersController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_ticket_follower, only: [:destroy]
  before_action :check_authorization

  def index
    @ticket_followers = @ticket.ticket_followers.includes(:user).order(:id)
  end

  def create
    @ticket_follower = @ticket.ticket_followers.create!(user_id: params[:user_id])
    log_activity(:follower_added, @ticket_follower.user)
    render 'show'
  # Following twice is a no-op, not an error - the unique index is what keeps
  # the list clean, and a double click should not surface a 422.
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    @ticket_follower = @ticket.ticket_followers.find_by!(user_id: params[:user_id])
    render 'show'
  end

  def destroy
    user = @ticket_follower.user
    @ticket_follower.destroy!
    log_activity(:follower_removed, user)
    head :ok
  end

  private

  def check_authorization(model = nil)
    super(model || @ticket_follower || TicketFollower)
  end

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def fetch_ticket_follower
    @ticket_follower = @ticket.ticket_followers.find(params[:id])
  end

  def log_activity(activity_type, user)
    @ticket.ticket_activities.create!(
      account_id: @ticket.account_id, user: Current.user,
      activity_type: activity_type, new_value: user.name, meta: { user_id: user.id }
    )
  end
end
