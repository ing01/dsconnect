import FormsAPI from '../../api/forms';

export const state = {
  records: [],
  responsesByForm: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isFetchingResponses: false,
  },
};

export const getters = {
  getForms(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getFormById: _state => id => {
    return _state.records.find(form => form.id === Number(id));
  },
  getResponsesByForm: _state => formId => {
    return _state.responsesByForm[formId] || [];
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await FormsAPI.get();
      commit('SET_FORMS', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  show: async ({ commit }, id) => {
    const response = await FormsAPI.show(id);
    commit('ADD_OR_UPDATE_FORM', response.data);
    return response.data;
  },
  create: async ({ commit }, data) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await FormsAPI.create({ form: data });
      commit('ADD_OR_UPDATE_FORM', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...data }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await FormsAPI.update(id, { form: data });
      commit('ADD_OR_UPDATE_FORM', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  delete: async ({ commit, dispatch }, id) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await FormsAPI.delete(id);
      dispatch('get');
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
  getResponses: async ({ commit }, formId) => {
    commit('SET_UI_FLAG', { isFetchingResponses: true });
    try {
      const response = await FormsAPI.getResponses(formId);
      commit('SET_RESPONSES', { formId, responses: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetchingResponses: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_FORMS(_state, records) {
    _state.records = records;
  },
  ADD_OR_UPDATE_FORM(_state, form) {
    const index = _state.records.findIndex(record => record.id === form.id);
    if (index === -1) {
      _state.records.push(form);
    } else {
      _state.records.splice(index, 1, form);
    }
  },
  SET_RESPONSES(_state, { formId, responses }) {
    _state.responsesByForm = { ..._state.responsesByForm, [formId]: responses };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
