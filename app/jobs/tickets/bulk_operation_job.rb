class Tickets::BulkOperationJob < ApplicationJob
  queue_as :medium

  def perform(operation_id)
    operation = TicketBulkOperation.find_by(id: operation_id)
    return if operation.nil? || !operation.pending?

    Current.user = operation.user
    Current.account = operation.account
    Tickets::BulkOperations::Runner.new(operation: operation).perform
  ensure
    Current.reset
  end
end
