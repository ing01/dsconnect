/* global axios */

import ApiClient from './ApiClient';

class TicketBulkOperationsAPI extends ApiClient {
  constructor() {
    super('ticket_bulk_operations', { accountScoped: true });
  }

  // `target` e { ticketIds } (escolhidos na tela) ou { filters } (todos do filtro).
  preview({ action, operation, ticketIds, filters }) {
    return axios.post(`${this.url}/preview`, {
      bulk_action: action,
      operation,
      ticket_ids: ticketIds,
      filters,
    });
  }

  run({ action, operation, ticketIds, filters }) {
    return axios.post(this.url, {
      bulk_action: action,
      operation,
      ticket_ids: ticketIds,
      filters,
    });
  }

  undo(id) {
    return axios.post(`${this.url}/${id}/undo`);
  }

  retryFailed(id) {
    return axios.post(`${this.url}/${id}/retry_failed`);
  }
}

export default new TicketBulkOperationsAPI();
