json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.icon resource.icon
json.icon_color resource.icon_color
json.account_id resource.account_id
json.active resource.active
json.manager_id resource.manager_id
json.assignee_levels_enabled resource.assignee_levels_enabled
json.assignee_levels_count resource.assignee_levels_count
json.handles_conversations resource.handles_conversations
json.handles_projects resource.handles_projects
# Os niveis que esta Mesa usa, ja resolvidos: a tela nao precisa saber que sem a
# configuracao ligada existe um nivel so.
json.assignee_levels resource.assignee_levels
json.is_member Current.user.teams.include?(resource)
