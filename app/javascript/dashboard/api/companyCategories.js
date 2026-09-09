/* global axios */
import ApiClient from './ApiClient';

class CompanyCategoryAPI extends ApiClient {
  constructor() {
    super('company_categories', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, { company_category: payload });
  }
}

export default new CompanyCategoryAPI();
