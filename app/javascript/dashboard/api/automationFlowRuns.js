/* global axios */

import ApiClient from './ApiClient';

class AutomationFlowRunsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getByConversation(conversationId) {
    return axios.get(`${this.url}/${conversationId}/automation_flow_runs`);
  }
}

export default new AutomationFlowRunsAPI();
