/* global axios */

import ApiClient from './ApiClient';

class TicketsAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  getByConversation(conversationId) {
    return axios.get(this.url, {
      params: { conversation_id: conversationId },
    });
  }

  createForConversation(conversationId, ticketData) {
    return axios.post(this.url, {
      ticket: ticketData,
      conversation_id: conversationId,
    });
  }

  move(id, { ticketColumnId, position }) {
    return axios.patch(`${this.url}/${id}/move`, {
      ticket_column_id: ticketColumnId,
      position,
    });
  }

  linkConversation(ticketId, conversationId) {
    return axios.post(`${this.url}/${ticketId}/ticket_conversations`, {
      ticket_conversation: { conversation_id: conversationId },
    });
  }

  unlinkConversation(ticketId, conversationId) {
    return axios.delete(
      `${this.url}/${ticketId}/ticket_conversations/${conversationId}`
    );
  }

  resolve(id) {
    return axios.patch(`${this.url}/${id}/resolve`);
  }

  reopen(id) {
    return axios.patch(`${this.url}/${id}/reopen`);
  }

  close(id) {
    return axios.patch(`${this.url}/${id}/close`);
  }

  getComments(ticketId) {
    return axios.get(`${this.url}/${ticketId}/comments`);
  }

  createComment(ticketId, content) {
    return axios.post(`${this.url}/${ticketId}/comments`, {
      ticket_comment: { content },
    });
  }

  deleteComment(ticketId, commentId) {
    return axios.delete(`${this.url}/${ticketId}/comments/${commentId}`);
  }

  getActivities(ticketId) {
    return axios.get(`${this.url}/${ticketId}/activities`);
  }

  // Provisions the default Mesa de Servico for an account that has none, so a
  // fresh install lands on a usable Kanban. Idempotent server-side.
  ensureDefaultMesa() {
    return axios.post(`${this.url}/ensure_default_mesa`);
  }
}

export default new TicketsAPI();
