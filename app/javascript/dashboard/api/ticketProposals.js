/* global axios */
import ApiClient from './ApiClient';

class TicketProposalsAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  getProposals(ticketId) {
    return axios.get(`${this.url}/${ticketId}/proposals`);
  }

  // Os dados da Empresa do ticket e os padroes comerciais, para o formulario
  // abrir preenchido.
  getDefaults(ticketId) {
    return axios.get(`${this.url}/${ticketId}/proposals/defaults`);
  }

  createProposal(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/proposals`, {
      ticket_proposal: data,
    });
  }

  updateProposal(ticketId, proposalId, data) {
    return axios.patch(`${this.url}/${ticketId}/proposals/${proposalId}`, {
      ticket_proposal: data,
    });
  }

  deleteProposal(ticketId, proposalId) {
    return axios.delete(`${this.url}/${ticketId}/proposals/${proposalId}`);
  }

  // O PDF vem pronto do servidor, entao a resposta e um arquivo.
  downloadPdf(ticketId, proposalId) {
    return axios.get(`${this.url}/${ticketId}/proposals/${proposalId}/pdf`, {
      responseType: 'blob',
    });
  }
}

export default new TicketProposalsAPI();
