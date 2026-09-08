json.array! @checklist_items do |item|
  json.partial! 'api/v1/models/ticket_checklist_item', formats: [:json], resource: item
end
