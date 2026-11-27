/* global axios */
import ApiClient from './ApiClient';

class CustomerBriefingAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getBriefing(conversationId, companyId) {
    return axios.get(`${this.url}/${conversationId}/customer_briefing`, {
      params: companyId ? { company_id: companyId } : {},
    });
  }

  summarize(conversationId, { companyId, force = false } = {}) {
    return axios.post(
      `${this.url}/${conversationId}/customer_briefing/summary`,
      {
        company_id: companyId || undefined,
        force,
      }
    );
  }
}

export default new CustomerBriefingAPI();
