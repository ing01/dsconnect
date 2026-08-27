import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import QueuesAPI from '../../api/queues';

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
  getQueues(_state) {
    return _state.records;
  },
  getQueuesByTeamId: _state => teamId => {
    return _state.records.filter(record => record.team_id === Number(teamId));
  },
  getQueueById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getQueues({ commit }) {
    commit(types.SET_QUEUES_UI_FLAG, { isFetching: true });
    try {
      const response = await QueuesAPI.get();
      commit(types.SET_QUEUES, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_QUEUES_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createQueue({ commit }, queueObj) {
    commit(types.SET_QUEUES_UI_FLAG, { isCreating: true });
    try {
      const response = await QueuesAPI.create(queueObj);
      commit(types.ADD_QUEUE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_QUEUES_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateQueue({ commit }, { id, ...updateObj }) {
    commit(types.SET_QUEUES_UI_FLAG, { isUpdating: true });
    try {
      const response = await QueuesAPI.update(id, updateObj);
      commit(types.EDIT_QUEUE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_QUEUES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteQueue({ commit }, id) {
    commit(types.SET_QUEUES_UI_FLAG, { isDeleting: true });
    try {
      await QueuesAPI.delete(id);
      commit(types.DELETE_QUEUE, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_QUEUES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_QUEUES_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_QUEUES]: MutationHelpers.set,
  [types.ADD_QUEUE]: MutationHelpers.create,
  [types.EDIT_QUEUE]: MutationHelpers.update,
  [types.DELETE_QUEUE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
