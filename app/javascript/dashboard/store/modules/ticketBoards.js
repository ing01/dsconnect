import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import TicketBoardsAPI from '../../api/ticketBoards';
import TicketsAPI from '../../api/tickets';

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
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getBoards(_state) {
    return _state.records;
  },
  getBoard: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_TICKET_BOARDS_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketBoardsAPI.get();
      commit(types.SET_TICKET_BOARDS, response.data);
    } finally {
      commit(types.SET_TICKET_BOARDS_UI_FLAG, { isFetching: false });
    }
  },
  fetchBoard: async ({ commit }, boardId) => {
    const response = await TicketBoardsAPI.show(boardId);
    commit(types.SET_TICKET_BOARD, response.data);
  },
  create: async ({ commit }, data) => {
    commit(types.SET_TICKET_BOARDS_UI_FLAG, { isCreating: true });
    try {
      const response = await TicketBoardsAPI.create({ ticket_board: data });
      commit(types.ADD_TICKET_BOARD, response.data);
      return response.data;
    } finally {
      commit(types.SET_TICKET_BOARDS_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...data }) => {
    commit(types.SET_TICKET_BOARDS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketBoardsAPI.update(id, {
        ticket_board: data,
      });
      commit(types.SET_TICKET_BOARD, response.data);
    } finally {
      commit(types.SET_TICKET_BOARDS_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_TICKET_BOARDS_UI_FLAG, { isDeleting: true });
    try {
      await TicketBoardsAPI.delete(id);
      commit(types.DELETE_TICKET_BOARD, id);
    } finally {
      commit(types.SET_TICKET_BOARDS_UI_FLAG, { isDeleting: false });
    }
  },
  createColumn: async ({ dispatch }, { boardId, ...data }) => {
    await TicketBoardsAPI.createColumn(boardId, data);
    await dispatch('fetchBoard', boardId);
  },
  updateColumn: async ({ dispatch }, { boardId, columnId, ...data }) => {
    await TicketBoardsAPI.updateColumn(boardId, columnId, data);
    await dispatch('fetchBoard', boardId);
  },
  deleteColumn: async ({ dispatch }, { boardId, columnId }) => {
    await TicketBoardsAPI.deleteColumn(boardId, columnId);
    await dispatch('fetchBoard', boardId);
  },
  reorderColumns: async ({ commit }, { boardId, columnIds }) => {
    const response = await TicketBoardsAPI.reorderColumns(boardId, columnIds);
    commit(types.SET_TICKET_BOARD, response.data);
  },
  createTicket: async ({ dispatch }, { boardId, ...data }) => {
    await TicketsAPI.create({ ticket: data });
    await dispatch('fetchBoard', boardId);
  },
  updateTicket: async ({ dispatch }, { boardId, id, ...data }) => {
    await TicketsAPI.update(id, { ticket: data });
    await dispatch('fetchBoard', boardId);
  },
  moveTicket: async ({ dispatch }, { boardId, id, ticketColumnId, position }) => {
    await TicketsAPI.move(id, { ticketColumnId, position });
    await dispatch('fetchBoard', boardId);
  },
  deleteTicket: async ({ dispatch }, { boardId, id }) => {
    await TicketsAPI.delete(id);
    await dispatch('fetchBoard', boardId);
  },
  linkConversation: async ({ dispatch }, { boardId, ticketId, conversationId }) => {
    await TicketsAPI.linkConversation(ticketId, conversationId);
    await dispatch('fetchBoard', boardId);
  },
  unlinkConversation: async (
    { dispatch },
    { boardId, ticketId, conversationId }
  ) => {
    await TicketsAPI.unlinkConversation(ticketId, conversationId);
    await dispatch('fetchBoard', boardId);
  },
};

export const mutations = {
  [types.SET_TICKET_BOARDS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_TICKET_BOARDS](_state, boards) {
    _state.records = boards;
  },
  [types.SET_TICKET_BOARD](_state, board) {
    const index = _state.records.findIndex(record => record.id === board.id);
    if (index === -1) {
      _state.records.push(board);
    } else {
      _state.records.splice(index, 1, board);
    }
  },
  [types.ADD_TICKET_BOARD]: MutationHelpers.create,
  [types.DELETE_TICKET_BOARD]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
