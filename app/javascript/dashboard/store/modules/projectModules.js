import ProjectModulesAPI from '../../api/projectModules';

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
  getModules(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getModuleById: _state => id => {
    return _state.records.find(m => m.id === Number(id));
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await ProjectModulesAPI.get();
      commit('SET_MODULES', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  // ProjectModulesController#project_module_params requires the scalar fields
  // nested under `project_module`; `task_template_ids` is read directly off
  // top-level params by `sync_task_templates!`, so it stays outside that
  // wrapper.
  create: async ({ commit, dispatch }, { task_template_ids, ...data }) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await ProjectModulesAPI.create({
        project_module: data,
        task_template_ids,
      });
      dispatch('get');
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  update: async ({ commit, dispatch }, { id, task_template_ids, ...data }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await ProjectModulesAPI.update(id, {
        project_module: data,
        task_template_ids,
      });
      dispatch('get');
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  delete: async ({ commit, dispatch }, id) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await ProjectModulesAPI.delete(id);
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
  SET_MODULES(_state, records) {
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
