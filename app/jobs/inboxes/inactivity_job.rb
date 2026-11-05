class Inboxes::InactivityJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Inbox.where("inactivity_config <> '{}'::jsonb").find_each do |inbox|
      Inboxes::InactivityService.new(inbox: inbox).perform if inbox.inactivity_supported?
    end
  end
end
