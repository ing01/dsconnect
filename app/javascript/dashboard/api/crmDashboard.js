import ApiClient from './ApiClient';

class CrmDashboardAPI extends ApiClient {
  constructor() {
    super('crm/dashboard', { accountScoped: true });
  }
}

export default new CrmDashboardAPI();
