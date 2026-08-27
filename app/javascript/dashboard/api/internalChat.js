/* global axios */

import ApiClient from './ApiClient';

// O Chat Interno tem endpoints proprios, separados das Conversations com
// clientes - sao coisas distintas e nunca compartilham dados.
class InternalChatAPI extends ApiClient {
  constructor() {
    super('chat_channels', { accountScoped: true });
  }

  createChannel({ name, description, visibility, memberIds }) {
    return axios.post(this.url, {
      name,
      description,
      visibility,
      member_ids: memberIds,
    });
  }

  // Abre a conversa com alguem, ou devolve a que ja existe.
  openDirect(userId) {
    return axios.post(`${this.url}/direct`, { user_id: userId });
  }

  getMessages(channelId, { before } = {}) {
    return axios.get(`${this.url}/${channelId}/messages`, {
      params: before ? { before } : {},
    });
  }

  sendMessage(channelId, { content, replyToId }) {
    return axios.post(`${this.url}/${channelId}/messages`, {
      content,
      reply_to_id: replyToId,
    });
  }

  markRead(channelId) {
    return axios.post(`${this.url}/${channelId}/read`);
  }

  toggleReaction(channelId, messageId, emoji) {
    return axios.post(
      `${this.url}/${channelId}/messages/${messageId}/toggle_reaction`,
      { emoji }
    );
  }
}

export default new InternalChatAPI();
