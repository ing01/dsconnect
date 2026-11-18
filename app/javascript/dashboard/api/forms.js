/* global axios */
import ApiClient from './ApiClient';

class FormsAPI extends ApiClient {
  constructor() {
    super('forms', { accountScoped: true });
  }

  getResponses(formId) {
    return axios.get(`${this.url}/${formId}/form_responses`);
  }

  getResponse(formId, responseId) {
    return axios.get(`${this.url}/${formId}/form_responses/${responseId}`);
  }
}

export default new FormsAPI();
