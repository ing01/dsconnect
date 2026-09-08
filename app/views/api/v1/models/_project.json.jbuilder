json.id resource.id
json.name resource.name
json.account_id resource.account_id
json.team_id resource.team_id
json.team_name resource.team.name
json.company_id resource.company_id
json.company_name resource.company&.name
json.contact_id resource.contact_id
json.contact_name resource.contact&.name
json.project_module_id resource.project_module_id
json.project_module_name resource.project_module&.name
json.implementer_id resource.implementer_id
json.implementer_name resource.implementer&.name
json.stage resource.stage
json.status resource.status
json.start_date resource.start_date
json.due_date resource.due_date
json.support_ends_on resource.support_ends_on
json.contract_signed_on resource.contract_signed_on
json.completion_type resource.completion_type
json.notes resource.notes
json.cancelled_at resource.cancelled_at
json.cancellation_reason resource.cancellation_reason
json.custom_attributes resource.custom_attributes
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.tickets_count resource.tickets.count
json.completed_tickets_count resource.tickets.where(status: [:resolved, :closed]).count
json.tickets_completed resource.tickets_completed?
json.total_hours resource.total_hours
json.tickets resource.tickets.order(:position, :id) do |ticket|
  json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
end
