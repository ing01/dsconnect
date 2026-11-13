import ApiClient from './ApiClient';

// Os modulos (cards) da aba Tutoriais da Area do Cliente, editados por
// administradores em Configuracoes > Tutoriais do Portal.
class ClientTutorialModulesAPI extends ApiClient {
  constructor() {
    super('client_tutorial_modules', { accountScoped: true });
  }
}

export default new ClientTutorialModulesAPI();
