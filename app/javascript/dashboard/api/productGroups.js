/* global axios */
import ApiClient from './ApiClient';

class ProductGroupAPI extends ApiClient {
  constructor() {
    super('product_groups', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, { product_group: payload });
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, { product_group: payload });
  }
}

export default new ProductGroupAPI();
