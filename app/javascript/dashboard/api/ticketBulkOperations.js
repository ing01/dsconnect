/* global axios */

import ApiClient from './ApiClient';

class TicketBulkOperationsAPI extends ApiClient {
  constructor() {
    super('ticket_bulk_operations', { accountScoped: true });
  }

  // `target` e { ticketIds } (escolhidos na tela) ou { filters } (todos do filtro).
  // `excludeFinalized`: so' usado pela troca de categoria em lote - pula
  // ticket fechado/cancelado mesmo que esteja no escopo, quando quem pediu
  // escolher "so' os abertos" na pergunta de confirmacao.
  preview({ action, operation, ticketIds, filters, excludeFinalized }) {
    return axios.post(`${this.url}/preview`, {
      bulk_action: action,
      operation,
      ticket_ids: ticketIds,
      filters,
      exclude_finalized: excludeFinalized,
    });
  }

  run({ action, operation, ticketIds, filters, excludeFinalized }) {
    return axios.post(this.url, {
      bulk_action: action,
      operation,
      ticket_ids: ticketIds,
      filters,
      exclude_finalized: excludeFinalized,
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
