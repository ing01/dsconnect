import types from '../mutation-types';
import SuggestionColumnsAPI from '../../api/suggestionColumns';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
  },
};

export const getters = {
  getColumns(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_SUGGESTION_COLUMNS_UI_FLAG, { isFetching: true });
    try {
      const response = await SuggestionColumnsAPI.get();
      commit(types.SET_SUGGESTION_COLUMNS, response.data);
      return response.data;
    } finally {
      commit(types.SET_SUGGESTION_COLUMNS_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ dispatch }, { name }) => {
    await SuggestionColumnsAPI.create({ suggestion_column: { name } });
    return dispatch('get');
  },
  update: async ({ dispatch }, { id, name }) => {
    await SuggestionColumnsAPI.update(id, { suggestion_column: { name } });
    return dispatch('get');
  },
  delete: async ({ dispatch }, id) => {
    await SuggestionColumnsAPI.delete(id);
    return dispatch('get');
  },
  reorder: async ({ commit }, columnIds) => {
    const response = await SuggestionColumnsAPI.reorder(columnIds);
    commit(types.SET_SUGGESTION_COLUMNS, response.data);
    return response.data;
  },
};

export const mutations = {
  [types.SET_SUGGESTION_COLUMNS_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SUGGESTION_COLUMNS](_state, columns) {
    _state.records = columns;
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
