/* global axios */
import ApiClient from './ApiClient';

class SystemModuleAPI extends ApiClient {
  constructor() {
    super('system_modules', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, { system_module: payload });
  }
}

export default new SystemModuleAPI();
