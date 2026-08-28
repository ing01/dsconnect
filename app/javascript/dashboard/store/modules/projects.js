import ProjectsAPI from '../../api/projects';

export const state = {
  records: [],
  selectedProject: null,
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getProjects(_state) {
    return _state.records;
  },
  getSelectedProject(_state) {
    return _state.selectedProject;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getProjectsByStage: _state => stage => {
    return _state.records.filter(project => project.stage === stage);
  },
};

export const actions = {
  get: async ({ commit }, params = {}) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await ProjectsAPI.get(params);
      commit('SET_PROJECTS', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  show: async ({ commit }, id) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await ProjectsAPI.show(id);
      commit('SET_SELECTED_PROJECT', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  create: async ({ commit, dispatch }, data) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await ProjectsAPI.create({ project: data });
      commit('ADD_PROJECT', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...data }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await ProjectsAPI.update(id, { project: data });
      commit('UPDATE_PROJECT', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  generateTickets: async ({ commit }, { projectId, tasks }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await ProjectsAPI.generateTickets(projectId, tasks);
      commit('UPDATE_PROJECT', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await ProjectsAPI.delete(id);
      commit('REMOVE_PROJECT', id);
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_PROJECTS(_state, records) {
    _state.records = records;
  },
  SET_SELECTED_PROJECT(_state, project) {
    _state.selectedProject = project;
  },
  ADD_PROJECT(_state, project) {
    _state.records.unshift(project);
  },
  UPDATE_PROJECT(_state, project) {
    const index = _state.records.findIndex(p => p.id === project.id);
    if (index !== -1) {
      _state.records.splice(index, 1, project);
    } else {
      _state.records.unshift(project);
    }
    if (_state.selectedProject?.id === project.id) {
      _state.selectedProject = project;
    }
  },
  REMOVE_PROJECT(_state, id) {
    _state.records = _state.records.filter(p => p.id !== id);
    if (_state.selectedProject?.id === id) {
      _state.selectedProject = null;
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
