json.payload do
  json.array! @ticket_complexities do |complexity|
    json.partial! 'api/v1/models/ticket_complexity', formats: [:json],
                  resource: complexity, team_ids: @team_ids_by_complexity[complexity.id] || []
  end
end
