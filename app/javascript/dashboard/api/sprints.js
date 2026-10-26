/* global axios */

import ApiClient from './ApiClient';

// Sprints belong to a Mesa de Servico (Team), exactly like Estagios/Categorias
// do, so these routes are nested under `teams`.
class SprintsAPI extends ApiClient {
  constructor() {
    super('teams', { accountScoped: true });
  }

  get(teamId) {
    return axios.get(`${this.url}/${teamId}/sprints`);
  }

  create(teamId, data) {
    return axios.post(`${this.url}/${teamId}/sprints`, { sprint: data });
  }

  update(teamId, sprintId, data) {
    return axios.patch(`${this.url}/${teamId}/sprints/${sprintId}`, {
      sprint: data,
    });
  }

  activate(teamId, sprintId) {
    return axios.post(`${this.url}/${teamId}/sprints/${sprintId}/activate`);
  }

  conclude(teamId, sprintId) {
    return axios.post(`${this.url}/${teamId}/sprints/${sprintId}/conclude`);
  }
}

export default new SprintsAPI();
