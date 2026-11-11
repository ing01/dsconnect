import ConversationAPI from '../../api/conversations';

/**
 * Conversas ABERTAS, atribuidas a quem esta logado, com mensagem nao lida.
 *
 * Alimenta o aviso "!" das abas do topo, do menu lateral e da aba do navegador.
 * Fica a parte da lista de conversas de proposito: aquela so tem o que a tela de
 * Conversas carregou, e o aviso precisa funcionar de qualquer tela.
 *
 * So guarda os numeros (display_id) das conversas: o aviso nao e' um contador.
 */
export const state = {
  conversationIds: [],
};

export const getters = {
  hasUnread: _state => _state.conversationIds.length > 0,
  getConversationIds: _state => _state.conversationIds,
};

// Varios eventos seguidos (ler, atribuir, mudar status) viram uma busca so.
const REFRESH_DELAY_MS = 1500;
let refreshTimer = null;

export const actions = {
  // A fonte da verdade: a lista do servidor, que ja traz `unread_count` de cada
  // conversa. Erro de rede nao derruba nada - o aviso so fica como estava.
  fetch: async ({ commit }) => {
    try {
      const response = await ConversationAPI.get({
        assigneeType: 'me',
        status: 'open',
        page: 1,
      });
      const chats = response?.data?.data?.payload || [];
      commit(
        'SET_CONVERSATION_IDS',
        chats.filter(chat => Number(chat.unread_count) > 0).map(chat => chat.id)
      );
    } catch (error) {
      // sem rede ou sem permissao: mantem o que ja se sabia
    }
  },

  // Eventos em que nao da' para saber o resultado de cabeca: refaz a busca, mas
  // agrupando. Quem le a conversa tira o aviso na hora (`markRead`) e o resto
  // espera a confirmacao do servidor.
  scheduleRefresh: ({ dispatch }) => {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(() => dispatch('fetch'), REFRESH_DELAY_MS);
  },

  // Chegou mensagem de cliente numa conversa MINHA: acende o aviso sem pedir nada
  // ao servidor (o evento ja diz de quem e' a conversa e quantas nao lidas ha).
  // Mensagem enviada por agente, ou de conversa de outra pessoa, nao conta.
  applyMessage: ({ commit, rootGetters }, data) => {
    const isIncoming = Number(data?.message_type) === 0;
    const conversation = data?.conversation;
    if (!isIncoming || !conversation) return;
    if (conversation.assignee_id !== rootGetters.getCurrentUserID) return;
    if (!(Number(conversation.unread_count) > 0)) return;

    commit('ADD_CONVERSATION_ID', data.conversation_id);
  },

  // A conversa foi lida (por mim, em qualquer aparelho): o aviso dela some na hora.
  markRead: ({ commit, dispatch }, conversationId) => {
    commit('REMOVE_CONVERSATION_ID', conversationId);
    dispatch('scheduleRefresh');
  },

  clear: ({ commit }) => {
    clearTimeout(refreshTimer);
    commit('SET_CONVERSATION_IDS', []);
  },
};

export const mutations = {
  SET_CONVERSATION_IDS(_state, ids) {
    _state.conversationIds = [...new Set(ids)];
  },
  ADD_CONVERSATION_ID(_state, id) {
    if (id === undefined || id === null) return;
    if (!_state.conversationIds.includes(id)) _state.conversationIds.push(id);
  },
  REMOVE_CONVERSATION_ID(_state, id) {
    _state.conversationIds = _state.conversationIds.filter(item => item !== id);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
