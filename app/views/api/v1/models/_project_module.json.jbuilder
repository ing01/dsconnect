json.id resource.id
json.name resource.name
json.description resource.description
json.account_id resource.account_id
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.task_templates resource.project_module_task_templates.order(:position, :id) do |join_row|
  template = join_row.project_task_template
  json.id template.id
  json.name template.name
  json.default_ticket_title template.default_ticket_title
  json.description template.description
  json.default_assignee_id template.default_assignee_id
  json.default_assignee_name template.default_assignee&.name
  json.due_days template.due_days
  json.next_project_stage template.next_project_stage
  json.checklist_id template.checklist_id
  json.checklist_name template.checklist&.name
  json.checklist_items template.checklist&.items
  json.position join_row.position
end
