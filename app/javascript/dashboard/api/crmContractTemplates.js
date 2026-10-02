/* global axios */
import ApiClient from './ApiClient';

class CrmContractTemplatesAPI extends ApiClient {
  constructor() {
    super('crm/contract_templates', { accountScoped: true });
  }

  create(formData) {
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new CrmContractTemplatesAPI();
