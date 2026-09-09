module Enterprise::Concerns::Contact
  extend ActiveSupport::Concern
  included do
    # `company` (via company_id) is the primary/first Empresa - kept for the
    # counter_cache and as the fallback everywhere a single company is still
    # expected. `companies` is the full set: a contact can work at more than
    # one Empresa.
    belongs_to :company, optional: true, counter_cache: true
    has_many :company_contacts, dependent: :destroy
    has_many :companies, through: :company_contacts
    has_many :campaign_recipients, dependent: :destroy_async

    after_commit :associate_company_from_email,
                 on: [:create, :update],
                 if: :should_associate_company?
    before_save :sync_company_name_from_company, if: :will_save_change_to_company_id?
    after_save :ensure_primary_company_membership, if: :saved_change_to_company_id?
    after_update_commit :record_company_activity, if: :saved_change_to_last_activity_at?
  end

  # Replaces the full set of companies this contact belongs to, keeping the
  # backward-compatible `company_id` primary in sync as the first of them (or
  # blank when the set is empty).
  def sync_companies!(ids)
    self.company_ids = ids
    update!(company_id: ids.first)
  end

  private

  def should_associate_company?
    # Only trigger if:
    # 1. Contact has an email
    # 2. Contact doesn't have a company yet
    # 3. Email was just set/changed
    # 4. Email was previously nil (first time getting email)
    # 5. The account has the Companies feature enabled
    # Feature check is last so unrelated contact updates short-circuit on the
    # cheap in-memory guards before touching the account (hot message-ingest path).
    email.present? &&
      company_id.nil? &&
      saved_change_to_email? &&
      saved_change_to_email.first.nil? &&
      account.feature_enabled?('companies')
  end

  def associate_company_from_email
    Contacts::CompanyAssociationService.new.associate_company_from_email(self)
  rescue StandardError => e
    Rails.logger.error("Failed to associate company for contact #{id}: #{e.message}")
    # Don't fail the contact save if the company association fails
  end

  def record_company_activity
    company&.record_activity_at!(last_activity_at) if last_activity_at.present?
  end

  def sync_company_name_from_company
    self.additional_attributes ||= {}

    if company_id.present?
      additional_attributes['company_name'] = company&.name
    else
      additional_attributes.delete('company_name')
    end
  end

  # Whatever path sets the primary `company_id` (old single-company API
  # clients, imports, direct attribute writes), the membership list should
  # always include it too.
  def ensure_primary_company_membership
    company_contacts.find_or_create_by!(company_id: company_id) if company_id.present?
  end
end
