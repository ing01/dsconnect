/* global axios */

import ApiClient from './ApiClient';

// O relatorio de tickets: uma linha por ticket, filtravel por cliente,
// status, responsavel, catalogo e periodo de abertura/fechamento.
class TicketReportsAPI extends ApiClient {
  constructor() {
    super('ticket_reports', { accountScoped: true });
  }

  fetch(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new TicketReportsAPI();
