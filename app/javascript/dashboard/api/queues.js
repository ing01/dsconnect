import ApiClient from './ApiClient';

class QueuesAPI extends ApiClient {
  constructor() {
    super('queues', { accountScoped: true });
  }
}

export default new QueuesAPI();
