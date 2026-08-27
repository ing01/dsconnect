/* global axios */

import ApiClient from './ApiClient';

// Steps live under a ConversationFlow, not as a standalone resource.
class FlowStepsAPI extends ApiClient {
  constructor() {
    super('conversation_flows', { accountScoped: true });
  }

  get(flowId) {
    return axios.get(`${this.url}/${flowId}/flow_steps`);
  }

  create(flowId, data) {
    return axios.post(`${this.url}/${flowId}/flow_steps`, { flow_step: data });
  }

  update(flowId, stepId, data) {
    return axios.patch(`${this.url}/${flowId}/flow_steps/${stepId}`, {
      flow_step: data,
    });
  }

  delete(flowId, stepId) {
    return axios.delete(`${this.url}/${flowId}/flow_steps/${stepId}`);
  }

  reorder(flowId, stepIds) {
    return axios.patch(`${this.url}/${flowId}/flow_steps/reorder`, {
      step_ids: stepIds,
    });
  }
}

export default new FlowStepsAPI();
