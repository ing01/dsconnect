import ApiClient from './ApiClient';

class ProjectModulesAPI extends ApiClient {
  constructor() {
    super('project_modules', { accountScoped: true });
  }
}

export default new ProjectModulesAPI();
