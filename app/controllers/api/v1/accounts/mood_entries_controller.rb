class Api::V1::Accounts::MoodEntriesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @mood_entries = filtered_mood_entries.includes(:user).order(entry_date: :desc, created_at: :desc)
  end

  def create
    @mood_entry = Current.account.mood_entries.find_or_initialize_by(
      user: Current.user,
      entry_date: Date.current
    )
    @mood_entry.mood = mood_entry_params[:mood]
    @mood_entry.save!
  end

  def today
    @mood_entry = Current.account.mood_entries.find_by(user: Current.user, entry_date: Date.current)
  end

  private

  def filtered_mood_entries
    entries = Current.account.mood_entries
    entries = entries.where(entry_date: parsed_date(params[:since])..) if parsed_date(params[:since])
    entries = entries.where(entry_date: ..parsed_date(params[:until])) if parsed_date(params[:until])
    entries = entries.where(user_id: params[:user_id]) if params[:user_id].present?
    entries = entries.where(mood: params[:mood]) if params[:mood].present?
    entries
  end

  def parsed_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError
    nil
  end

  def mood_entry_params
    params.require(:mood_entry).permit(:mood)
  end
end
