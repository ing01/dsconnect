json.payload do
  json.partial! 'api/v1/accounts/companies/credentials/credential', formats: [:json], resource: @credential
end
