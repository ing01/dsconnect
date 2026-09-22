class Companies::RecalculatePrioritiesJob < ApplicationJob
  queue_as :low

  def perform(account_id:)
    account = Account.find_by(id: account_id)
    return if account.blank?

    recalculated = 0
    account.companies.find_each do |company|
      company.save!
      recalculated += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[Companies::RecalculatePrioritiesJob] company #{company.id}: #{e.message}")
    end

    Rails.logger.info "Recalculated priority for #{recalculated} companies on account #{account_id}"
  end
end
