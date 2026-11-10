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

  // Marca a sala como nao lida: a ultima mensagem de outra pessoa volta a contar.
  markRoomUnread(channelId) {
    return axios.post(`${this.url}/${channelId}/mark_unread`);
  }

  // Volta o ponto de leitura para esta mensagem: ela e as seguintes voltam a
  // contar como nao lidas (contador do menu e notificacoes).
  markMessageUnread(channelId, messageId) {
    return axios.post(
      `${this.url}/${channelId}/messages/${messageId}/mark_unread`
    );
  }

  toggleReaction(channelId, messageId, emoji) {
    return axios.post(
      `${this.url}/${channelId}/messages/${messageId}/toggle_reaction`,
      { emoji }
    );
  }

  deleteChannel(channelId) {
    return axios.delete(`${this.url}/${channelId}`);
  }

  addMember(channelId, userId) {
    return axios.post(`${this.url}/${channelId}/add_member`, {
      user_id: userId,
    });
  }

  removeMember(channelId, userId) {
    return axios.delete(`${this.url}/${channelId}/remove_member`, {
      data: { user_id: userId },
    });
  }

  getPinnedMessages(channelId) {
    return axios.get(`${this.url}/${channelId}/messages/pinned`);
  }

  togglePin(channelId, messageId) {
    return axios.post(
      `${this.url}/${channelId}/messages/${messageId}/toggle_pin`
    );
  }
}

export default new InternalChatAPI();
