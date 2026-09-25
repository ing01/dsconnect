json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.blocked resource.blocked
# Acesso a Area do Cliente. Vai no proprio contato porque e ele que tem o
# acesso - nao ha cadastro de cliente em outro lugar para consultar.
json.client_access_enabled resource.client_access_enabled
json.client_access_ready resource.client_access?
json.client_tickets_visibility resource.client_tickets_visibility
json.client_last_sign_in_at resource.client_last_sign_in_at&.to_i
json.identifier resource.identifier
if Current.account&.feature_enabled?('companies')
  json.company_id resource.company_id
  json.company_ids resource.company_ids
  json.companies resource.companies.map { |company| { id: company.id, name: company.name } }
end
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! resource.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end
