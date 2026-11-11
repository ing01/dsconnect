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
    json.development_type ticket.development_type
    # A key do card no Jira (aba Desenvolvimento); busca por ela: `?jira_key=`.
    json.jira_key ticket.jira_key
    json.sprint_id ticket.sprint_id
    json.team_id ticket.team_id
    json.team_name ticket.team.name
    json.ticket_column_id ticket.ticket_column_id
    json.ticket_column_name ticket.ticket_column&.name
    json.ticket_category_id ticket.ticket_category_id
    json.ticket_category_name ticket.ticket_category&.name
    json.company_id ticket.company_id
    json.company_name ticket.company&.name
    json.assignee_id ticket.assignee_id
    json.assignee_name ticket.assignee&.name
    json.created_at ticket.created_at.iso8601
    json.updated_at ticket.updated_at.iso8601
    # Os campos do card do Jira, ja na lista (nil quando nao preenchidos).
    Ticket::LONG_TEXT_CUSTOM_ATTRIBUTES.each do |field|
      json.set! field, ticket.custom_attributes[field]
    end
  end
end
