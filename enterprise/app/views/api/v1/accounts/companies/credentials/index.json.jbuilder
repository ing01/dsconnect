json.payload do
  json.array! @credentials do |credential|
    json.partial! 'api/v1/accounts/companies/credentials/credential', formats: [:json], resource: credential
  end
end
