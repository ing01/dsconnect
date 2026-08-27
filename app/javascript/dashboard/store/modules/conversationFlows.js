import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ConversationFlowsAPI from '../../api/conversationFlows';

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
  getConversationFlows(_state) {
    return _state.records;
  },
  getConversationFlow: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getConversationFlows({ commit }) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isFetching: true });
    try {
      const response = await ConversationFlowsAPI.get();
      commit(types.SET_CONVERSATION_FLOWS, response.data);
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isFetching: false });
    }
  },

  show: async function showConversationFlow({ commit }, id) {
    const response = await ConversationFlowsAPI.show(id);
    commit(types.SET_CONVERSATION_FLOW_ITEM, response.data);
    return response.data;
  },

  create: async function createConversationFlow({ commit }, flowObj) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isCreating: true });
    try {
      const response = await ConversationFlowsAPI.create(flowObj);
      commit(types.ADD_CONVERSATION_FLOW, response.data);
      return response.data;
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateConversationFlow({ commit }, { id, ...updateObj }) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ConversationFlowsAPI.update(id, updateObj);
      commit(types.EDIT_CONVERSATION_FLOW, response.data);
      return response.data;
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteConversationFlow({ commit }, id) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isDeleting: true });
    try {
      await ConversationFlowsAPI.delete(id);
      commit(types.DELETE_CONVERSATION_FLOW, id);
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CONVERSATION_FLOWS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_CONVERSATION_FLOWS]: MutationHelpers.set,
  [types.SET_CONVERSATION_FLOW_ITEM]: MutationHelpers.setSingleRecord,
  [types.ADD_CONVERSATION_FLOW]: MutationHelpers.create,
  [types.EDIT_CONVERSATION_FLOW]: MutationHelpers.update,
  [types.DELETE_CONVERSATION_FLOW]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
