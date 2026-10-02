import ApiClient from './ApiClient';

class CrmClientsAPI extends ApiClient {
  constructor() {
    super('crm/clients', { accountScoped: true });
  }
}

export default new CrmClientsAPI();
