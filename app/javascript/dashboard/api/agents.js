/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  // Atalho administrativo. A recuperacao por e-mail continua existindo; esta
  // rota serve onde aquele e-mail nao chega.
  resetPassword(agentId, password) {
    return axios.post(`${this.url}/${agentId}/reset_password`, { password });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }
}

export default new Agents();
