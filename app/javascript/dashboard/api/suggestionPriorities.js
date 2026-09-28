import ApiClient from './ApiClient';

class SuggestionPrioritiesAPI extends ApiClient {
  constructor() {
    super('suggestion_priorities', { accountScoped: true });
  }
}

export default new SuggestionPrioritiesAPI();
