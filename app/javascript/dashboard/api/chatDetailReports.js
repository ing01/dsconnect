/* global axios */

import ApiClient from './ApiClient';

// O relatorio "Chat detalhado": uma linha por conversa, com o resumo do periodo, e o
// mesmo em Excel (duas abas: Chat Detalhado e Resumo).
class ChatDetailReportsAPI extends ApiClient {
  constructor() {
    super('chat_detail_reports', { accountScoped: true });
  }

  fetch(params = {}) {
    return axios.get(this.url, { params });
  }

  // O arquivo vem pronto do servidor, com os mesmos filtros da tela e sem paginacao.
  exportXlsx(params = {}) {
    return axios.get(`${this.url}/export`, { params, responseType: 'blob' });
  }
}

export default new ChatDetailReportsAPI();
