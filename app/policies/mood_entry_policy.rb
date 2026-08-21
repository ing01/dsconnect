class MoodEntryPolicy < ApplicationPolicy
  def create?
    true
  end

  def today?
    true
  end

  def index?
    @account_user.administrator?
  end
end
