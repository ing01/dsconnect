class Companies::ContactMembershipService
  attr_reader :company

  def initialize(company:)
    @company = company
  end

  # Adds this Empresa to the contact's companies without disturbing any
  # others they already belong to. Only becomes the primary `company_id`
  # when the contact doesn't have one yet.
  def assign(contact:)
    contact.company_contacts.find_or_create_by!(company: company)
    contact.update!(company_id: company.id) if contact.company_id.blank?
    company.record_activity_at!(contact.last_activity_at) if contact.last_activity_at.present?
  end

  # Removes just this Empresa. If it was the primary, the next remaining
  # company (if any) takes over as primary.
  def remove(contact:)
    contact.company_contacts.find_by(company: company)&.destroy
    return unless contact.company_id == company.id

    contact.update!(company_id: contact.company_contacts.order(:id).first&.company_id)
  end
end
