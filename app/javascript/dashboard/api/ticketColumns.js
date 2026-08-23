/* global axios */

import ApiClient from './ApiClient';

// Estagios (Kanban stages/columns) now live under a Mesa de Servico (Team),
// not a standalone board - these routes are nested under `teams`.
class TicketColumnsAPI extends ApiClient {
  constructor() {
    super('teams', { accountScoped: true });
  }

  create(teamId, data) {
    return axios.post(`${this.url}/${teamId}/ticket_columns`, {
      ticket_column: data,
    });
  }

  update(teamId, columnId, data) {
    return axios.patch(`${this.url}/${teamId}/ticket_columns/${columnId}`, {
      ticket_column: data,
    });
  }

  delete(teamId, columnId) {
    return axios.delete(`${this.url}/${teamId}/ticket_columns/${columnId}`);
  }

  reorder(teamId, columnIds) {
    return axios.patch(`${this.url}/${teamId}/ticket_columns/reorder`, {
      column_ids: columnIds,
    });
  }
}

export default new TicketColumnsAPI();
