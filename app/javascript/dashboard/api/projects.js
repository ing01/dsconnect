import ApiClient from './ApiClient';

class ProjectsAPI extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
  }

  // Contadores das abas (ativos / concluidos / cancelados), com os mesmos filtros da lista.
  counts(params = {}) {
    return axios.get(`${this.url}/counts`, { params });
  }

  generateTickets(projectId, tasks) {
    return axios.post(`${this.url}/${projectId}/generate_tickets`, { tasks });
  }

  cancel(projectId, reason) {
    return axios.post(`${this.url}/${projectId}/cancel`, { reason });
  }

  reactivate(projectId) {
    return axios.post(`${this.url}/${projectId}/reactivate`);
  }

  createSchedule(projectId, items) {
    return axios.post(`${this.url}/${projectId}/create_schedule`, { items });
  }
}

export default new ProjectsAPI();
