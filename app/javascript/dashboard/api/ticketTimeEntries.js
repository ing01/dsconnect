/* global axios */
import ApiClient from './ApiClient';

class TicketTimeEntriesAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  getEntries(ticketId) {
    return axios.get(`${this.url}/${ticketId}/time_entries`);
  }

  createEntry(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/time_entries`, {
      ticket_time_entry: data,
    });
  }

  updateEntry(ticketId, entryId, data) {
    return axios.patch(`${this.url}/${ticketId}/time_entries/${entryId}`, {
      ticket_time_entry: data,
    });
  }

  // Cronometro de apontamento: so o proprio agente enxerga e mexe nos seus.
  getTimers(ticketId) {
    return axios.get(`${this.url}/${ticketId}/timers`);
  }

  startTimer(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/timers`, data);
  }

  pauseTimer(ticketId, timerId) {
    return axios.post(`${this.url}/${ticketId}/timers/${timerId}/pause`);
  }

  resumeTimer(ticketId, timerId) {
    return axios.post(`${this.url}/${ticketId}/timers/${timerId}/resume`);
  }

  // Devolve o apontamento criado com o tempo.
  finishTimer(ticketId, timerId) {
    return axios.post(`${this.url}/${ticketId}/timers/${timerId}/finish`);
  }

  discardTimer(ticketId, timerId) {
    return axios.delete(`${this.url}/${ticketId}/timers/${timerId}`);
  }

  deleteEntry(ticketId, entryId) {
    return axios.delete(`${this.url}/${ticketId}/time_entries/${entryId}`);
  }
}

export default new TicketTimeEntriesAPI();
