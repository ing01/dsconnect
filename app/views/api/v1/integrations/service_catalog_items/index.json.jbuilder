json.array! @service_catalogs do |catalog|
  json.id catalog.id
  json.name catalog.name
  json.areas catalog.service_catalog_areas.select(&:active?) do |area|
    json.id area.id
    json.name area.name
    json.items area.service_catalog_items.select(&:active?) do |item|
      json.id item.id
      json.name item.name
    end
  end
end
