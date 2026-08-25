/* global axios */

import ApiClient from './ApiClient';

// Categories belong to a Mesa de Servico (Team), exactly like Estagios do, so
// these routes are nested under `teams`.
class TicketCategoriesAPI extends ApiClient {
  constructor() {
    super('teams', { accountScoped: true });
  }

  get(teamId) {
    return axios.get(`${this.url}/${teamId}/ticket_categories`);
  }

  create(teamId, data) {
    return axios.post(`${this.url}/${teamId}/ticket_categories`, {
      ticket_category: data,
    });
  }

  update(teamId, categoryId, data) {
    return axios.patch(
      `${this.url}/${teamId}/ticket_categories/${categoryId}`,
      {
        ticket_category: data,
      }
    );
  }

  delete(teamId, categoryId) {
    return axios.delete(
      `${this.url}/${teamId}/ticket_categories/${categoryId}`
    );
  }
}

export default new TicketCategoriesAPI();
