json.id generated_contract.id
json.crm_contract_template_id generated_contract.crm_contract_template_id
json.template_name generated_contract.template&.name
json.crm_client_id generated_contract.crm_client_id
json.client_name generated_contract.client&.name
json.crm_sale_id generated_contract.crm_sale_id
json.pdf_url generated_contract.pdf_url
json.pdf_name generated_contract.pdf_name
json.docx_url generated_contract.docx_url
json.docx_name generated_contract.docx_name
json.created_at generated_contract.created_at.to_i

# Versoes anteriores (antes de uma troca de representante, por exemplo) -
# ver Crm::Contracts::RegenerationService/Crm::GeneratedContractRevision.
json.revisions generated_contract.revisions.sort_by(&:created_at).reverse do |revision|
  json.id revision.id
  json.pdf_url revision.pdf_url
  json.reason revision.reason
  json.created_at revision.created_at.to_i
end
