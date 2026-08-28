import ApiClient from './ApiClient';

class ProjectsAPI extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
  }

  generateTickets(projectId, tasks) {
    return axios.post(`${this.url}/${projectId}/generate_tickets`, { tasks });
  }
}

export default new ProjectsAPI();
