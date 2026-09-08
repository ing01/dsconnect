import ApiClient from './ApiClient';

class ProjectsAPI extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
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
}

export default new ProjectsAPI();
