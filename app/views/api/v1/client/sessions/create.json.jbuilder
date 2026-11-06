json.api_access_token @token
json.password_change_required @password_change_required
json.contact do
  json.partial! 'api/v1/client/models/contact', resource: @contact
end
