/* global axios */
import ApiClient from './ApiClient';

// O SAC do lado da equipe: as manifestacoes registradas pelos clientes no
// Portal, mais as que a propria equipe anotou ao receber por telefone.
//
// `show`, `create`, `update` e `destroy` vem do ApiClient. O que esta classe
// acrescenta sao as acoes que nao sao um CRUD: filtrar a listagem, escrever
// (resposta publica ou anotacao interna) e converter em ticket.
class ManifestationsAPI extends ApiClient {
  constructor() {
    super('manifestations', { accountScoped: true });
  }

  // Os filtros da tela: empresa, tipo, assunto, status, solicitante, periodo e
  // busca livre. Quem monta a consulta e o ManifestationFinder, no servidor.
  list(filters = {}) {
    return axios.get(this.url, { params: filters });
  }

  // `internal: true` grava ANOTACAO INTERNA, que o cliente nunca ve.
  // `awaitingCustomer` responde e passa a manifestacao para "aguardando
  // retorno" na mesma acao - e o que o agente faz quando faz uma pergunta.
  reply(id, { body, internal = false, awaitingCustomer = false }) {
    return axios.post(`${this.url}/${id}/messages`, {
      body,
      internal,
      awaiting_customer: awaitingCustomer,
    });
  }

  // Cria o ticket pelo mecanismo existente e guarda o vinculo. O servidor
  // recusa a segunda chamada - nao e a tela que impede a duplicidade.
  convert(id, { teamId = null, ticketCategoryId = null } = {}) {
    return axios.post(`${this.url}/${id}/convert`, {
      ...(teamId ? { team_id: teamId } : {}),
      ...(ticketCategoryId ? { ticket_category_id: ticketCategoryId } : {}),
    });
  }
}

export default new ManifestationsAPI();
