/* global axios */

import ApiClient from './ApiClient';

// O relatorio de apontamentos de tickets: horas por nivel e por pessoa.
// Somente leitura - o que ele soma sao os apontamentos que a aba do ticket
// grava, e nao um registro proprio.
class TicketTimeReportsAPI extends ApiClient {
  constructor() {
    super('ticket_time_reports', { accountScoped: true });
  }

  // Todos os filtros sao opcionais e se acumulam: periodo, Mesa, nivel,
  // pessoa e categoria.
  fetch(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new TicketTimeReportsAPI();
