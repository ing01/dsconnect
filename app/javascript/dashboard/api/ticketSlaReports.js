/* global axios */

import ApiClient from './ApiClient';

// O relatorio de SLA de tickets: cumprimento por agente e por Cliente,
// combinado ou por tipo de relogio. Somente leitura - o que ele soma sao os
// TicketAppliedSla que o proprio ticket ja mantem.
class TicketSlaReportsAPI extends ApiClient {
  constructor() {
    super('ticket_sla_reports', { accountScoped: true });
  }

  // Todos os filtros sao opcionais e se acumulam: periodo, Mesa, Cliente e
  // tipo de relogio.
  fetch(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new TicketSlaReportsAPI();
