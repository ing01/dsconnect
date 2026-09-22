/* global axios */
import ApiClient from './ApiClient';

class ProductAPI extends ApiClient {
  constructor() {
    super('products', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, { product: payload });
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, { product: payload });
  }
}

export default new ProductAPI();
