class Api::V1::Accounts::ServiceCatalogsController < Api::V1::Accounts::BaseController
  before_action :fetch_service_catalog, only: [:update, :destroy]
  before_action :check_authorization

  # The whole tree in one request: it is small, and both the settings screen and
  # the classification dialog need all three levels at once.
  #
  # `service_catalog_items: :forms` must be preloaded too: the item partial
  # reads `form_ids`, and without this every item issues its own query for it -
  # fine for a handful of items, but an account with thousands of them (this
  # one has 2400+) never finishes before the request times out. Found by
  # investigating the catalog picker coming up empty in production (2026-11-23).
  def index
    @service_catalogs = Current.account.service_catalogs
                               .includes(service_catalog_areas: { service_catalog_items: :forms })
                               .ordered
  end

  def create
    @service_catalog = Current.account.service_catalogs.create!(service_catalog_params)
  end

  def update
    @service_catalog.update!(service_catalog_params)
  end

  # Deactivation is the ordinary path (see the policy note); destroy exists for
  # a catalogue created by mistake and is refused once tickets depend on it.
  def destroy
    @service_catalog.destroy!
    head :ok
  end

  private

  def fetch_service_catalog
    @service_catalog = Current.account.service_catalogs.find(params[:id])
  end

  def check_authorization(model = nil)
    super(model || @service_catalog || ServiceCatalog)
  end

  def service_catalog_params
    params.require(:service_catalog).permit(:name, :active, :position)
  end
end
