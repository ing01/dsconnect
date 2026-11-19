json.array! @users do |user|
  json.partial! 'api/v1/integrations/users/user', user: user, roles: @roles, niches: @niches, sub_niches: @sub_niches
end
