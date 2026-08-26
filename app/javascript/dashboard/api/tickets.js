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

  getAttachments(ticketId) {
    return axios.get(`${this.url}/${ticketId}/attachments`);
  }

  // Plain multipart: the generic /upload blob endpoint would need two
  // round-trips (blob, then attach) and carries no size guard of its own.
  createAttachment(ticketId, file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/${ticketId}/attachments`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  deleteAttachment(ticketId, attachmentId) {
    return axios.delete(`${this.url}/${ticketId}/attachments/${attachmentId}`);
  }

  // One entry point for every creation path. `conversationId` links the chat the
  // ticket was opened from; `parentId` is handled by `create_child`, which also
  // carries the copy options the form cannot express.
  createTicket({ ticket, conversationId }) {
    return axios.post(this.url, { ticket, conversation_id: conversationId });
  }

  // The three ids together: the server walks the hierarchy and refuses an
  // Area that is not in the Catalogo, or an Item that is not in the Area.
  classify(id, { serviceCatalogId, serviceCatalogAreaId, serviceCatalogItemId }) {
    return axios.patch(`${this.url}/${id}/classify`, {
      service_catalog_id: serviceCatalogId,
      service_catalog_area_id: serviceCatalogAreaId,
      service_catalog_item_id: serviceCatalogItemId,
    });
  }

  getCustomerCommunications(ticketId) {
    return axios.get(`${this.url}/${ticketId}/customer_communications`);
  }

  // Synchronous on the server: the response says whether the message actually
  // left, which is what the closing flow depends on.
  // No subject: the server titles every customer message with the ticket
  // header, the closing notice included.
  sendCustomerCommunication(ticketId, { body, closing }) {
    return axios.post(`${this.url}/${ticketId}/customer_communications`, {
      body,
      closing,
    });
  }

  cancel(id, reason) {
    return axios.patch(`${this.url}/${id}/cancel`, { reason });
  }

  // Mesa, Estagio, Status, Prioridade and Responsavel in one auditable step.
  transfer(id, ticket) {
    return axios.patch(`${this.url}/${id}/transfer`, { ticket });
  }

  // `options` says which parts of the parent to copy; `ticket` carries the
  // fields the agent chose not to copy and typed instead.
  createChild(id, { options, ticket }) {
    return axios.post(`${this.url}/${id}/create_child`, { options, ticket });
  }

  // A blank `parentId` clears the reference - `belongs_to :parent` holds one.
  setParent(id, parentId) {
    return axios.patch(`${this.url}/${id}/set_parent`, {
      parent_id: parentId || null,
    });
  }

  // `id` survives; `sourceId` is closed into it.
  merge(id, sourceId) {
    return axios.post(`${this.url}/${id}/merge`, { source_id: sourceId });
  }

  duplicate(id) {
    return axios.post(`${this.url}/${id}/duplicate`);
  }

  assignToMe(id) {
    return axios.patch(`${this.url}/${id}/assign_to_me`);
  }

  addSlaHours(id, { hours, reason }) {
    return axios.post(`${this.url}/${id}/add_sla_hours`, { hours, reason });
  }

  getFollowers(ticketId) {
    return axios.get(`${this.url}/${ticketId}/followers`);
  }

  addFollower(ticketId, userId) {
    return axios.post(`${this.url}/${ticketId}/followers`, { user_id: userId });
  }

  removeFollower(ticketId, followerId) {
    return axios.delete(`${this.url}/${ticketId}/followers/${followerId}`);
  }

  // Backs the ticket pickers in "Referenciar ticket pai" and "Agrupar ticket".
  // `q` already matches both the ticket number and the title server-side.
  search(query, params = {}) {
    return axios.get(this.url, {
      params: { q: query, per_page: 20, ...params },
    });
  }

  // Provisions the default Mesa de Servico for an account that has none, so a
  // fresh install lands on a usable Kanban. Idempotent server-side.
  ensureDefaultMesa() {
    return axios.post(`${this.url}/ensure_default_mesa`);
  }
}

export default new TicketsAPI();
