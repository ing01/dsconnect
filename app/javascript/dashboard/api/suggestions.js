/* global axios */

import ApiClient from './ApiClient';

class SuggestionsAPI extends ApiClient {
  constructor() {
    super('suggestions', { accountScoped: true });
  }

  // JSON simples quando nao ha anexo; com arquivo, precisa de multipart - o
  // mesmo motivo de TicketsAPI#createAttachment.
  create({ suggestion, files = [] }) {
    if (!files.length) {
      return axios.post(this.url, { suggestion });
    }

    const formData = new FormData();
    Object.entries(suggestion).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        formData.append(`suggestion[${key}]`, value);
      }
    });
    files.forEach(file => formData.append('suggestion[files][]', file));

    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  block(id, reason) {
    return axios.post(`${this.url}/${id}/block`, { reason });
  }

  unblock(id) {
    return axios.post(`${this.url}/${id}/unblock`);
  }

  move(id, { suggestionColumnId, position }) {
    return axios.patch(`${this.url}/${id}/move`, {
      suggestion_column_id: suggestionColumnId,
      position,
    });
  }
}

export default new SuggestionsAPI();
