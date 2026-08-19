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
}

export default new TicketsAPI();
