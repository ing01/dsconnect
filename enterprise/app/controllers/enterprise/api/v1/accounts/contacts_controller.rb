module Enterprise::Api::V1::Accounts::ContactsController
  def create
    ActiveRecord::Base.transaction do
      super
      sync_contact_companies!
    end
  end

  def update
    ActiveRecord::Base.transaction do
      super
      sync_contact_companies!
    end
  end

  private

  def permitted_params
    params_with_company_id = super
    return params_with_company_id unless Current.account.feature_enabled?('companies')
    return params_with_company_id unless params.key?(:company_id)

    params_with_company_id.merge(company_id: permitted_company_id)
  end

  def permitted_company_id
    return nil if params[:company_id].blank?

    Current.account.companies.find(params[:company_id]).id
  end

  # A contact can now work at more than one Empresa - `company_ids` (plural)
  # replaces the full set when the client sends it, alongside the
  # backward-compatible single `company_id`.
  def sync_contact_companies!
    return unless Current.account.feature_enabled?('companies')
    return unless params.key?(:company_ids)
    return if @contact.blank?

    ids = Current.account.companies.where(id: Array(params[:company_ids]).compact_blank).pluck(:id)
    @contact.sync_companies!(ids)
  end
end
