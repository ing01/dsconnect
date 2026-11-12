import ApiClient from './ApiClient';

class ConversationDistributionAPI extends ApiClient {
  constructor() {
    super('conversation_distribution', { accountScoped: true });
  }

  distribute() {
    return this.create({});
  }
}

export default new ConversationDistributionAPI();
