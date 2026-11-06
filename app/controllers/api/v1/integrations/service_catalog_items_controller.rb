# Lista o Catalogo de Servicos inteiro (3 niveis: Catalogo > Area > Item),
# para a IA/sistema externo saber quais ids de Item sao validos em
# `service_catalog_item_id` no `PATCH /integrations/tickets/:id/route` - o
# unico nivel que um Ticket aponta de verdade (ver ServiceCatalogItem).
class Api::V1::Integrations::ServiceCatalogItemsController < Api::V1::Integrations::BaseController
  def index
    @service_catalogs = current_account.service_catalogs.active.ordered
                                       .includes(service_catalog_areas: :service_catalog_items)
  end
end
