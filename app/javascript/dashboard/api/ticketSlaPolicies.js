/* global axios */

import ApiClient from './ApiClient';

// A matriz Mesa x Prioridade dos prazos de atendimento e solução, e o expediente
// da Mesa que esses prazos respeitam. Aninhados em `teams` porque são
// configuração da Mesa, como os Estágios e as Categorias.
class TicketSlaPoliciesAPI extends ApiClient {
  constructor() {
    super('teams', { accountScoped: true });
  }

  get(teamId) {
    return axios.get(`${this.url}/${teamId}/ticket_sla_policies`);
  }

  create(teamId, data) {
    return axios.post(`${this.url}/${teamId}/ticket_sla_policies`, {
      ticket_sla_policy: data,
    });
  }

  update(teamId, policyId, data) {
    return axios.patch(
      `${this.url}/${teamId}/ticket_sla_policies/${policyId}`,
      { ticket_sla_policy: data }
    );
  }

  delete(teamId, policyId) {
    return axios.delete(
      `${this.url}/${teamId}/ticket_sla_policies/${policyId}`
    );
  }

  getWorkingHours(teamId) {
    return axios.get(`${this.url}/${teamId}/working_hours`);
  }

  updateWorkingHours(teamId, data) {
    return axios.patch(`${this.url}/${teamId}/working_hours`, data);
  }
}

export default new TicketSlaPoliciesAPI();
