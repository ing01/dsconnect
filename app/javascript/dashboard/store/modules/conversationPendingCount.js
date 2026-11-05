import ConversationApi from '../../api/inbox/conversation';
import types from '../mutation-types';

// O badge de "Conversas"/"Todas as conversas" na barra lateral: o total de
// conversas PENDENTES na conta inteira (sem filtro de inbox/label/time -
// `meta` sem inbox_id ja' varre todas as inboxes que o usuario enxerga, do
// jeito que ConversationFinder#set_up resolve o escopo).
//
// Modulo separado de `conversationUnreadCounts` de proposito: aquele e'
// usado tambem pelos badges por inbox/label/time (nao-lidas), que nao mudam
// aqui - misturar os dois estados no mesmo modulo faria uma busca
// sobrescrever o resultado da outra.
export const state = {
  pendingCount: 0,
};

export const getters = {
  getPendingCount($state) {
    return $state.pendingCount;
  },
};

export const actions = {
  get: async ({ commit }) => {
    try {
      const {
        data: { meta },
      } = await ConversationApi.meta({ status: 'pending' });
      commit(types.SET_CONVERSATION_PENDING_COUNT, meta?.all_count || 0);
    } catch (error) {
      // Ignora - o badge so' fica sem numero, nao impede o resto da barra.
    }
  },
};

export const mutations = {
  [types.SET_CONVERSATION_PENDING_COUNT]($state, count) {
    $state.pendingCount = Number(count) || 0;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
