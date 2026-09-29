import types from '../mutation-types';
import SuggestionPrioritiesAPI from '../../api/suggestionPriorities';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
  },
};

export const getters = {
  getItems(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_SUGGESTION_PRIORITIES_UI_FLAG, { isFetching: true });
    try {
      const response = await SuggestionPrioritiesAPI.get();
      commit(types.SET_SUGGESTION_PRIORITIES, response.data);
      return response.data;
    } finally {
      commit(types.SET_SUGGESTION_PRIORITIES_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ dispatch }, { name, color }) => {
    await SuggestionPrioritiesAPI.create({
      suggestion_priority: { name, color },
    });
    return dispatch('get');
  },
  update: async ({ dispatch }, { id, name, color }) => {
    await SuggestionPrioritiesAPI.update(id, {
      suggestion_priority: { name, color },
    });
    return dispatch('get');
  },
  delete: async ({ dispatch }, id) => {
    await SuggestionPrioritiesAPI.delete(id);
    return dispatch('get');
  },
};

export const mutations = {
  [types.SET_SUGGESTION_PRIORITIES_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SUGGESTION_PRIORITIES](_state, items) {
    _state.records = items;
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
