import ApiClient from './ApiClient';

class ChecklistsAPI extends ApiClient {
  constructor() {
    super('checklists', { accountScoped: true });
  }
}

export default new ChecklistsAPI();
