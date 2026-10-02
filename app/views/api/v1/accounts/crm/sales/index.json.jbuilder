json.array! @sales do |sale|
  json.partial! 'sale', sale: sale
end
