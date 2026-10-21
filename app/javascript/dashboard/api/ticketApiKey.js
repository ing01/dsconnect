/* global axios */
import ApiClient from './ApiClient';

// A chave da API de Integracao de Tickets - singular de proposito (uma por
// conta), por isso os metodos sao escritos a mao em vez de herdar show/delete
// do ApiClient (que esperam um :id na URL).
class TicketApiKeyAPI extends ApiClient {
  constructor() {
    super('ticket_api_key', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  generate() {
    return axios.post(this.url);
  }

  revoke() {
    return axios.delete(this.url);
  }
}

export default new TicketApiKeyAPI();
