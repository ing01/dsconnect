/* eslint-disable max-classes-per-file -- dois recursos pequenos do mesmo painel */
/* global axios */
import ApiClient from './ApiClient';

// Os numeros do Painel de Conversas (API v2).
class ConversationPanelAPI extends ApiClient {
  constructor() {
    super('conversation_panel', { accountScoped: true, apiVersion: 'v2' });
  }
}

// Os tempos e o ritmo do painel (Configuracoes, so' administrador). E' um
// recurso unico por conta: sem id na URL.
class ConversationPanelSettingsAPI extends ApiClient {
  constructor() {
    super('conversation_panel_setting', { accountScoped: true });
  }

  show() {
    return axios.get(this.url);
  }

  save(payload) {
    return axios.put(this.url, { conversation_panel_setting: payload });
  }
}

export const conversationPanelSettingsAPI = new ConversationPanelSettingsAPI();
export default new ConversationPanelAPI();
