import ApiClient from './ApiClient';

// Os niveis de Complexidade do ticket. Lista da CONTA - como o Catalogo de
// Servicos e diferente da Categoria, que e da Mesa. Quais Mesas oferecem cada
// nivel vai no proprio registro (`team_ids`).
class TicketComplexitiesAPI extends ApiClient {
  constructor() {
    super('ticket_complexities', { accountScoped: true });
  }
}

export default new TicketComplexitiesAPI();
