/* global axios */
import ApiClient from './ApiClient';

const buildParams = params =>
  new URLSearchParams(
    Object.entries(params).filter(
      ([key, value]) => value !== undefined && (value !== '' || key === 'q')
    )
  ).toString();

class ContractAPI extends ApiClient {
  constructor() {
    super('contracts', { accountScoped: true });
  }

  get(params = {}) {
    const { page = 1 } = params;
    const requestURL = `${this.url}?${buildParams({ page })}`;
    return axios.get(requestURL);
  }

  search(query = '', page = 1) {
    const requestURL = `${this.url}/search?${buildParams({ q: query, page })}`;
    return axios.get(requestURL);
  }

  create(payload) {
    return axios.post(this.url, { contract: payload });
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, { contract: payload });
  }
}

export default new ContractAPI();
