import ApiClient from './ApiClient';

class ProjectTaskTemplatesAPI extends ApiClient {
  constructor() {
    super('project_task_templates', { accountScoped: true });
  }
}

export default new ProjectTaskTemplatesAPI();
