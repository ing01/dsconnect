import ApiClient from './ApiClient';

class HelpdeskOverviewAPI extends ApiClient {
  constructor() {
    super('helpdesk_overview', { accountScoped: true, apiVersion: 'v2' });
  }
}

export default new HelpdeskOverviewAPI();
