/* global axios */

import ApiClient from './ApiClient';

// The whole Catalogo > Area > Item tree comes back in one request: it is small,
// and both the settings screen and the classification dialog need all three
// levels at once.
class ServiceCatalogsAPI extends ApiClient {
  constructor() {
    super('service_catalogs', { accountScoped: true });
  }

  createArea(catalogId, data) {
    return axios.post(`${this.url}/${catalogId}/areas`, {
      service_catalog_area: data,
    });
  }

  updateArea(catalogId, areaId, data) {
    return axios.patch(`${this.url}/${catalogId}/areas/${areaId}`, {
      service_catalog_area: data,
    });
  }

  deleteArea(catalogId, areaId) {
    return axios.delete(`${this.url}/${catalogId}/areas/${areaId}`);
  }

  createItem(catalogId, areaId, data) {
    return axios.post(`${this.url}/${catalogId}/areas/${areaId}/items`, {
      service_catalog_item: data,
    });
  }

  updateItem(catalogId, areaId, itemId, data) {
    return axios.patch(
      `${this.url}/${catalogId}/areas/${areaId}/items/${itemId}`,
      { service_catalog_item: data }
    );
  }

  deleteItem(catalogId, areaId, itemId) {
    return axios.delete(
      `${this.url}/${catalogId}/areas/${areaId}/items/${itemId}`
    );
  }
}

export default new ServiceCatalogsAPI();
