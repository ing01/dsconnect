class PagesController < ActionController::Base
  def privacy_policy
    render layout: false
  end

  def account_deletion
    render layout: false
  end
end
