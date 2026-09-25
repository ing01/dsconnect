/* global axios */
import ApiClient from './ApiClient';

class TicketImportsAPI extends ApiClient {
  constructor() {
    super('ticket_imports', { accountScoped: true });
  }

  import(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new TicketImportsAPI();
