/* global axios */
import ApiClient from './ApiClient';

class CompanyNicheAPI extends ApiClient {
  constructor() {
    super('company_niches', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, { company_niche: payload });
  }
}

export default new CompanyNicheAPI();
