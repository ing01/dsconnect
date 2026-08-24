json.id resource.id
json.title resource.title
json.description resource.description
json.start_at resource.start_at.to_i
json.end_at resource.end_at.to_i
json.all_day resource.all_day
json.location resource.location
json.color resource.color
json.team_id resource.team_id
json.created_by_id resource.created_by_id
json.created_by_name resource.created_by&.name
json.attendees resource.attendees.map { |attendee| { id: attendee.id, name: attendee.name } }
json.tickets resource.tickets.map { |ticket| { id: ticket.id, display_id: ticket.display_id, title: ticket.title } }
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
