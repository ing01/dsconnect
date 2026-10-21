json.meta do
  json.count @tickets_count
  json.current_page @current_page
end

json.payload do
  json.array! @tickets do |ticket|
    json.id ticket.id
    json.display_id ticket.display_id
    json.title ticket.title
    json.status ticket.status
    json.priority ticket.priority
    json.team_id ticket.team_id
    json.team_name ticket.team.name
    json.ticket_category_id ticket.ticket_category_id
    json.ticket_category_name ticket.ticket_category&.name
    json.company_id ticket.company_id
    json.company_name ticket.company&.name
    json.created_at ticket.created_at.iso8601
  end
end
