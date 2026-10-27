json.array! @ticket_proposals do |proposal|
  json.partial! 'api/v1/models/ticket_proposal', formats: [:json], resource: proposal
end
