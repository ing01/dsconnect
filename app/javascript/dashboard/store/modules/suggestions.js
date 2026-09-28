import types from '../mutation-types';
import SuggestionsAPI from '../../api/suggestions';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

export const getters = {
  getSuggestions(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_SUGGESTIONS_UI_FLAG, { isFetching: true });
    try {
      const response = await SuggestionsAPI.get();
      commit(types.SET_SUGGESTIONS, response.data);
      return response.data;
    } finally {
      commit(types.SET_SUGGESTIONS_UI_FLAG, { isFetching: false });
    }
  },
  // `assigneeId` so tem efeito quando quem envia administra o quadro - o
  // backend ignora o campo silenciosamente pra qualquer outro agente.
  create: async ({ commit }, { title, description, assigneeId }) => {
    commit(types.SET_SUGGESTIONS_UI_FLAG, { isCreating: true });
    try {
      const response = await SuggestionsAPI.create({
        suggestion: { title, description, assignee_id: assigneeId },
      });
      commit(types.UPSERT_SUGGESTION, response.data);
      return response.data;
    } finally {
      commit(types.SET_SUGGESTIONS_UI_FLAG, { isCreating: false });
    }
  },
  updateAssignee: async ({ commit }, { id, assigneeId }) => {
    const response = await SuggestionsAPI.update(id, {
      suggestion: { assignee_id: assigneeId },
    });
    commit(types.UPSERT_SUGGESTION, response.data);
    return response.data;
  },
  move: async ({ commit }, { id, suggestionColumnId, position }) => {
    const response = await SuggestionsAPI.move(id, {
      suggestionColumnId,
      position,
    });
    commit(types.UPSERT_SUGGESTION, response.data);
    return response.data;
  },
  delete: async ({ commit }, id) => {
    await SuggestionsAPI.delete(id);
    commit(types.REMOVE_SUGGESTION, id);
  },
};

export const mutations = {
  [types.SET_SUGGESTIONS_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SUGGESTIONS](_state, suggestions) {
    _state.records = suggestions;
  },
  [types.UPSERT_SUGGESTION](_state, suggestion) {
    const index = _state.records.findIndex(
      record => record.id === suggestion.id
    );
    if (index === -1) {
      _state.records.push(suggestion);
    } else {
      _state.records.splice(index, 1, suggestion);
    }
  },
  [types.REMOVE_SUGGESTION](_state, id) {
    _state.records = _state.records.filter(record => record.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
