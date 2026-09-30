import types from '../mutation-types';
import TicketComplexitiesAPI from '../../api/ticketComplexities';

/**
 * Os niveis de Complexidade do ticket.
 *
 * Lista da CONTA, e nao da Mesa: o nome e o mesmo em toda a empresa, e o que
 * varia e quais Mesas oferecem cada nivel (`team_ids`). Por isso vive num modulo
 * proprio e nao dentro de `ticketColumns`, que guarda o que e por Mesa.
 *
 * A lista e pequena e vem inteira: a tela de configuracao precisa dela completa
 * (inclusive os desativados) e o formulario de ticket filtra a partir dela.
 */
export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getUIFlags: _state => _state.uiFlags,
  // Tudo, inclusive desativado: e o que a tela de configuracao lista.
  getComplexities: _state => _state.records,

  // O que um agente pode escolher NAQUELA Mesa. Desativado nao aparece em Mesa
  // nenhuma, e a Mesa que nao oferece o nivel simplesmente nao o recebe - a
  // mesma regra que o servidor aplica, e nao uma segunda versao dela.
  getComplexitiesForTeam: _state => teamId => {
    if (!teamId) return [];

    return _state.records.filter(
      item => item.active && (item.team_ids || []).includes(Number(teamId))
    );
  },
};

export const actions = {
  fetch: async ({ commit }) => {
    commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketComplexitiesAPI.get();
      commit(types.SET_TICKET_COMPLEXITIES, response.data.payload);
      return response.data.payload;
    } finally {
      commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isFetching: false });
    }
  },

  // Toda alteracao relê a lista em vez de remendá-la aqui: o pedido é pequeno, e
  // a alternativa é manter uma segunda cópia da matriz que pode divergir.
  create: async ({ dispatch, commit }, data) => {
    commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isUpdating: true });
    try {
      await TicketComplexitiesAPI.create({ ticket_complexity: data });
      return dispatch('fetch');
    } finally {
      commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isUpdating: false });
    }
  },

  update: async ({ dispatch, commit }, { id, ...data }) => {
    commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isUpdating: true });
    try {
      await TicketComplexitiesAPI.update(id, { ticket_complexity: data });
      return dispatch('fetch');
    } finally {
      commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ dispatch, commit }, id) => {
    commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isUpdating: true });
    try {
      await TicketComplexitiesAPI.delete(id);
      return dispatch('fetch');
    } finally {
      commit(types.SET_TICKET_COMPLEXITY_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_TICKET_COMPLEXITY_UI_FLAG](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  [types.SET_TICKET_COMPLEXITIES](_state, records) {
    _state.records = records || [];
  },
};

export default { namespaced: true, state, getters, actions, mutations };
