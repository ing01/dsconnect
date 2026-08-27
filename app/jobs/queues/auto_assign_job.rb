class Queues::AutoAssignJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Queues::DistributionService.new(conversation.reload).perform
  end
end
