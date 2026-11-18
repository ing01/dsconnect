import ApiClient from './ApiClient';

// Os avisos do Mural do Portal do Cliente, editados por administradores em
// Configuracoes > Avisos do Portal.
class ClientAnnouncementsAPI extends ApiClient {
  constructor() {
    super('client_announcements', { accountScoped: true });
  }
}

export default new ClientAnnouncementsAPI();
