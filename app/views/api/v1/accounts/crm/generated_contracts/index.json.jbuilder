json.array! @contracts do |contract|
  json.partial! 'generated_contract', generated_contract: contract
end
