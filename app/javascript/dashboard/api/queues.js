/* global axios */
import ApiClient from './ApiClient';

class QueuesAPI extends ApiClient {
  constructor() {
    super('queues', { accountScoped: true });
  }

  claimNext() {
    return axios.post(`${this.url}/claim_next`);
  }
}

export default new QueuesAPI();
