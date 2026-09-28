/* global axios */

import ApiClient from './ApiClient';

class SuggestionsAPI extends ApiClient {
  constructor() {
    super('suggestions', { accountScoped: true });
  }

  move(id, { suggestionColumnId, position }) {
    return axios.patch(`${this.url}/${id}/move`, {
      suggestion_column_id: suggestionColumnId,
      position,
    });
  }
}

export default new SuggestionsAPI();
