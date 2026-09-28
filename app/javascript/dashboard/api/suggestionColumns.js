/* global axios */

import ApiClient from './ApiClient';

class SuggestionColumnsAPI extends ApiClient {
  constructor() {
    super('suggestion_columns', { accountScoped: true });
  }

  reorder(columnIds) {
    return axios.patch(`${this.url}/reorder`, { column_ids: columnIds });
  }
}

export default new SuggestionColumnsAPI();
