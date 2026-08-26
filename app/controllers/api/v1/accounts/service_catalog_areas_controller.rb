class Api::V1::Accounts::ServiceCatalogAreasController < Api::V1::Accounts::BaseController
  before_action :fetch_service_catalog
  before_action :fetch_area, only: [:update, :destroy]
  before_action :check_authorization

  def create
    @service_catalog_area = @service_catalog.service_catalog_areas.create!(area_params)
  end

  def update
    @service_catalog_area.update!(area_params)
  end

  def destroy
    @service_catalog_area.destroy!
    head :ok
  end

  private

  def fetch_service_catalog
    @service_catalog = Current.account.service_catalogs.find(params[:service_catalog_id])
  end

  def fetch_area
    @service_catalog_area = @service_catalog.service_catalog_areas.find(params[:id])
  end

  def check_authorization(model = nil)
    super(model || ServiceCatalog)
  end

  def area_params
    params.require(:service_catalog_area).permit(:name, :active, :position)
  end
end
