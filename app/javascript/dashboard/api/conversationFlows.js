import ApiClient from './ApiClient';

class ConversationFlowsAPI extends ApiClient {
  constructor() {
    super('conversation_flows', { accountScoped: true });
  }
}

export default new ConversationFlowsAPI();
