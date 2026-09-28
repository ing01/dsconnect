import types from '../mutation-types';
import SuggestionCategoriesAPI from '../../api/suggestionCategories';

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
    commit(types.SET_SUGGESTION_CATEGORIES_UI_FLAG, { isFetching: true });
    try {
      const response = await SuggestionCategoriesAPI.get();
      commit(types.SET_SUGGESTION_CATEGORIES, response.data);
      return response.data;
    } finally {
      commit(types.SET_SUGGESTION_CATEGORIES_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ dispatch }, { name }) => {
    await SuggestionCategoriesAPI.create({ suggestion_category: { name } });
    return dispatch('get');
  },
  update: async ({ dispatch }, { id, name }) => {
    await SuggestionCategoriesAPI.update(id, { suggestion_category: { name } });
    return dispatch('get');
  },
  delete: async ({ dispatch }, id) => {
    await SuggestionCategoriesAPI.delete(id);
    return dispatch('get');
  },
};

export const mutations = {
  [types.SET_SUGGESTION_CATEGORIES_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SUGGESTION_CATEGORIES](_state, items) {
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
