json.payload @companies do |company|
  json.partial! 'api/v1/integrations/companies/company', company: company
end
json.meta do
  json.count @companies_count
  json.current_page @current_page
end
