/* global axios */

import ApiClient from './ApiClient';

// O Chat Interno tem endpoints proprios, separados das Conversations com
// clientes - sao coisas distintas e nunca compartilham dados.
class InternalChatAPI extends ApiClient {
  constructor() {
    super('chat_channels', { accountScoped: true });
  }

  createChannel({
    name,
    description,
    visibility,
    memberIds,
    pinned,
    postingPolicy,
    moderatorIds,
  }) {
    return axios.post(this.url, {
      name,
      description,
      visibility,
      member_ids: memberIds,
      pinned,
      posting_policy: postingPolicy,
      moderator_ids: moderatorIds,
    });
  }

  // Ajustar o canal depois de criado: fixar, restringir quem escreve, renomear.
  updateChannel(
    channelId,
    { name, description, pinned, postingPolicy, moderatorIds }
  ) {
    return axios.patch(`${this.url}/${channelId}`, {
      name,
      description,
      pinned,
      posting_policy: postingPolicy,
      moderator_ids: moderatorIds,
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

  // `attachments` sao signed ids de blobs que ja subiram para o storage, e nao
  // os arquivos: os bytes nunca passam por este pedido.
  sendMessage(channelId, { content, replyToId, attachments }) {
    return axios.post(`${this.url}/${channelId}/messages`, {
      content,
      reply_to_id: replyToId,
      attachments,
    });
  }

  // O endereco que o navegador usa para registrar o blob antes de enviar o
  // arquivo direto ao storage.
  directUploadUrl(channelId) {
    return `${this.url}/${channelId}/direct_uploads`;
  }

  deleteMessage(channelId, messageId) {
    return axios.delete(`${this.url}/${channelId}/messages/${messageId}`);
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
