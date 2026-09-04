import ApiClient from './ApiClient';

class TicketChecklistItemsAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  getItems(ticketId) {
    return axios.get(`${this.url}/${ticketId}/checklist_items`);
  }

  createItem(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/checklist_items`, { checklist_item: data });
  }

  toggleItem(ticketId, itemId) {
    return axios.patch(`${this.url}/${ticketId}/checklist_items/${itemId}/toggle`);
  }

  updateItem(ticketId, itemId, data) {
    return axios.patch(`${this.url}/${ticketId}/checklist_items/${itemId}`, { checklist_item: data });
  }

  attachChecklist(ticketId, checklistId) {
    return axios.post(`${this.url}/${ticketId}/checklist_items/attach_checklist`, { checklist_id: checklistId });
  }

  deleteItem(ticketId, itemId) {
    return axios.delete(`${this.url}/${ticketId}/checklist_items/${itemId}`);
  }
}

export default new TicketChecklistItemsAPI();
