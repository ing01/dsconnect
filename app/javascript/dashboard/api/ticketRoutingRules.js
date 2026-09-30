/* global axios */
import ApiClient from './ApiClient';

class TicketRoutingRules extends ApiClient {
  constructor() {
    super('ticket_routing_rules', { accountScoped: true });
  }

  bulkUpdate(rules) {
    return axios.post(`${this.url}/bulk_update`, {
      ticket_routing_rules: rules,
    });
  }
}

export default new TicketRoutingRules();
