json.array! @templates do |template|
  json.partial! 'contract_template', contract_template: template
end
