import types from '../mutation-types';
import FlowStepsAPI from '../../api/flowSteps';

export const state = {
  recordsByFlow: {},
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getSteps: _state => flowId => _state.recordsByFlow[flowId] || [],
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  fetch: async ({ commit }, flowId) => {
    if (!flowId) return [];

    commit(types.SET_FLOW_STEPS_UI_FLAG, { isFetching: true });
    try {
      const response = await FlowStepsAPI.get(flowId);
      commit(types.SET_FLOW_STEPS, { flowId, steps: response.data });
      return response.data;
    } finally {
      commit(types.SET_FLOW_STEPS_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ dispatch }, { flowId, ...data }) => {
    await FlowStepsAPI.create(flowId, data);
    return dispatch('fetch', flowId);
  },

  update: async ({ dispatch }, { flowId, stepId, ...data }) => {
    await FlowStepsAPI.update(flowId, stepId, data);
    return dispatch('fetch', flowId);
  },

  delete: async ({ dispatch }, { flowId, stepId }) => {
    await FlowStepsAPI.delete(flowId, stepId);
    return dispatch('fetch', flowId);
  },

  reorder: async ({ dispatch }, { flowId, stepIds }) => {
    await FlowStepsAPI.reorder(flowId, stepIds);
    return dispatch('fetch', flowId);
  },
};

export const mutations = {
  [types.SET_FLOW_STEPS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_FLOW_STEPS](_state, { flowId, steps }) {
    _state.recordsByFlow = { ..._state.recordsByFlow, [flowId]: steps };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
