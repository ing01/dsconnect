/* global axios */
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

  // `answers` e `files` sao hashes field_id => valor/arquivo - o backend
  // (TicketChecklistItemsController#fill_form) le os dois direto de
  // `params[:answers]`/`params[:files]`, sem precisar de strong params.
  fillForm(ticketId, itemId, { answers, files }) {
    const formData = new FormData();
    Object.entries(answers || {}).forEach(([fieldId, value]) => {
      if (Array.isArray(value)) {
        value.forEach(item => formData.append(`answers[${fieldId}][]`, item));
      } else if (value !== '' && value !== null && value !== undefined) {
        formData.append(`answers[${fieldId}]`, value);
      }
    });
    Object.entries(files || {}).forEach(([fieldId, file]) => {
      if (file) formData.append(`files[${fieldId}]`, file);
    });

    return axios.post(
      `${this.url}/${ticketId}/checklist_items/${itemId}/fill_form`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } }
    );
  }

  attachChecklist(ticketId, checklistId) {
    return axios.post(`${this.url}/${ticketId}/checklist_items/attach_checklist`, { checklist_id: checklistId });
  }

  deleteItem(ticketId, itemId) {
    return axios.delete(`${this.url}/${ticketId}/checklist_items/${itemId}`);
  }
}

export default new TicketChecklistItemsAPI();
