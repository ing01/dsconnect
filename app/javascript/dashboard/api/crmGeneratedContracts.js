import ApiClient from './ApiClient';

class CrmGeneratedContractsAPI extends ApiClient {
  constructor() {
    super('crm/generated_contracts', { accountScoped: true });
  }
}

export default new CrmGeneratedContractsAPI();
