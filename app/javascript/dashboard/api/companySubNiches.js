/* global axios */
import ApiClient from './ApiClient';

class CompanySubNicheAPI extends ApiClient {
  constructor() {
    super('company_sub_niches', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, { company_sub_niche: payload });
  }
}

export default new CompanySubNicheAPI();
