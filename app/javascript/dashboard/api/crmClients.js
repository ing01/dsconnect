/* global axios */
import ApiClient from './ApiClient';

class CrmClientsAPI extends ApiClient {
  constructor() {
    super('crm/clients', { accountScoped: true });
  }

  // So' os dados do representante NOVO - atualiza o cliente e regenera, no
  // servidor, todos os contratos ja gerados para ele (ver
  // Crm::Contracts::RegenerationService).
  changeRepresentative(id, payload) {
    return axios.patch(`${this.url}/${id}/change_representative`, {
      crm_client: payload,
    });
  }
}

export default new CrmClientsAPI();
