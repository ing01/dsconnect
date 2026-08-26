FactoryBot.define do
  factory :service_catalog do
    account
    sequence(:name) { |n| "Catálogo #{n}" }
  end

  factory :service_catalog_area do
    service_catalog
    sequence(:name) { |n| "Área #{n}" }
  end

  factory :service_catalog_item do
    service_catalog_area
    sequence(:name) { |n| "Item #{n}" }
  end
end
