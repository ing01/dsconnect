import ApiClient from './ApiClient';

class CrmSalesAPI extends ApiClient {
  constructor() {
    super('crm/sales', { accountScoped: true });
  }
}

export default new CrmSalesAPI();
