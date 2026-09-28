import ApiClient from './ApiClient';

class SuggestionCategoriesAPI extends ApiClient {
  constructor() {
    super('suggestion_categories', { accountScoped: true });
  }
}

export default new SuggestionCategoriesAPI();
