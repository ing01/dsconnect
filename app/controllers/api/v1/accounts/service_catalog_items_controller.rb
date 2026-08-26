class Api::V1::Accounts::ServiceCatalogItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_area
  before_action :fetch_item, only: [:update, :destroy]
  before_action :check_authorization

  def create
    @service_catalog_item = @service_catalog_area.service_catalog_items.create!(item_params)
  end

  def update
    @service_catalog_item.update!(item_params)
  end

  # `has_many :tickets, dependent: :restrict_with_error` refuses this once a
  # ticket was classified with the item; deactivating is what admins do then.
  def destroy
    @service_catalog_item.destroy!
    head :ok
  end

  private

  def fetch_area
    catalog = Current.account.service_catalogs.find(params[:service_catalog_id])
    @service_catalog_area = catalog.service_catalog_areas.find(params[:area_id])
  end

  def fetch_item
    @service_catalog_item = @service_catalog_area.service_catalog_items.find(params[:id])
  end

  def check_authorization(model = nil)
    super(model || ServiceCatalog)
  end

  def item_params
    params.require(:service_catalog_item).permit(:name, :active, :position)
  end
end
