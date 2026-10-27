class Queues::InactivityJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ServiceQueue.active.with_inactivity_rules.find_each do |queue|
      Queues::InactivityService.new(queue: queue).perform
    end
  end
end
