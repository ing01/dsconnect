json.array! @checklists do |checklist|
  json.partial! 'api/v1/models/checklist', formats: [:json], resource: checklist
end
