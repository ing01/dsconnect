json.api_access_token @token
json.contact do
  json.partial! 'api/v1/client/models/contact', resource: @contact
end
