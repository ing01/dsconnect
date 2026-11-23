# Aplica a Gestao de clientes (edicao em massa) fora da requisicao e vai
# gravando o andamento em `CompanyBulkUpdate`, que a tela mostra como "log da
# alteracao". Uma Empresa que falhe entra na lista de erros e nao impede as demais.
class Companies::BulkUpdateJob < ApplicationJob
  queue_as :low

  def perform(account_id:, company_ids:, changes:, bulk_update_id: nil)
    account = Account.find_by(id: account_id)
    return if account.blank?

    record = CompanyBulkUpdate.find_by(id: bulk_update_id, account_id: account_id)
    record&.update!(status: 'running', started_at: Time.current)

    result = run_service(account, company_ids, changes, record)
    finish(record, result)
  rescue StandardError => e
    Rails.logger.error("[Companies::BulkUpdateJob] account #{account_id}: #{e.class}: #{e.message}")
    record&.update(status: 'failed', finished_at: Time.current, error_message: I18n.t('errors.companies.bulk_update.job_failed'))
  end

  private

  def run_service(account, company_ids, changes, record)
    Companies::BulkUpdateService.new(
      account: account,
      companies: account.companies.where(id: company_ids),
      changes: changes.with_indifferent_access,
      on_progress: lambda { |processed, updated, failed|
        record&.update_columns(processed_count: processed, updated_count: updated, failed_count: failed) # rubocop:disable Rails/SkipsModelValidations
      }
    ).perform
  end

  def finish(record, result)
    return if record.blank?

    if result[:error]
      record.update!(status: 'failed', finished_at: Time.current, error_message: result[:error])
      return
    end

    failures = result[:failed]
    record.update!(
      status: 'completed', finished_at: Time.current, processed_count: result[:updated] + failures.size,
      updated_count: result[:updated], failed_count: failures.size,
      failures: failures.first(CompanyBulkUpdate::MAX_FAILURES).map(&:stringify_keys)
    )
  end
end
