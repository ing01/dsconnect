import ApiClient from './ApiClient';

// Os tutoriais da Area do Cliente, editados por administradores em
// Configuracoes > Tickets > Tutoriais do Portal.
class ClientTutorialsAPI extends ApiClient {
  constructor() {
    super('client_tutorials', { accountScoped: true });
  }

  // Onde o navegador registra o blob do video antes de envia-lo direto ao storage.
  directUploadUrl() {
    return `${this.baseUrl()}/client_tutorial_uploads`;
  }
}

export default new ClientTutorialsAPI();
