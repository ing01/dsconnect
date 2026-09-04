import ApiClient from './ApiClient';

class TicketTimeEntriesAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  getEntries(ticketId) {
    return axios.get(`${this.url}/${ticketId}/time_entries`);
  }

  createEntry(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/time_entries`, { ticket_time_entry: data });
  }

  updateEntry(ticketId, entryId, data) {
    return axios.patch(`${this.url}/${ticketId}/time_entries/${entryId}`, { ticket_time_entry: data });
  }

  deleteEntry(ticketId, entryId) {
    return axios.delete(`${this.url}/${ticketId}/time_entries/${entryId}`);
  }
}

export default new TicketTimeEntriesAPI();
