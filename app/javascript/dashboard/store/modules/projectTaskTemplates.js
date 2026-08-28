import ProjectTaskTemplatesAPI from '../../api/projectTaskTemplates';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getTaskTemplates(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getTaskTemplateById: _state => id => {
    return _state.records.find(t => t.id === Number(id));
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await ProjectTaskTemplatesAPI.get();
      commit('SET_TASK_TEMPLATES', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  create: async ({ commit, dispatch }, data) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await ProjectTaskTemplatesAPI.create({ project_task_template: data });
      dispatch('get');
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  update: async ({ commit, dispatch }, { id, ...data }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await ProjectTaskTemplatesAPI.update(id, { project_task_template: data });
      dispatch('get');
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  delete: async ({ commit, dispatch }, id) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await ProjectTaskTemplatesAPI.delete(id);
      dispatch('get');
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_TASK_TEMPLATES(_state, records) {
    _state.records = records;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
