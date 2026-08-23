import types from '../mutation-types';
import TicketsAPI from '../../api/tickets';

// Holds ticket state that is not scoped to a single Mesa's Kanban board: the
// flat, filterable/paginated list used by "Busca detalhada", a single
// ticket used by the detail page, and that ticket's comments/activity
// timeline. Kanban board/column/drag-and-drop state lives in
// `ticketColumns.js` (the ticket-Kanban view of a Team/Mesa de Servico).
export const state = {
  records: [],
  listMeta: { count: 0, currentPage: 1 },
  comments: {},
  activities: {},
  uiFlags: {
    isFetchingList: false,
    isFetchingItem: false,
    isUpdating: false,
    isFetchingComments: false,
    isCreatingComment: false,
    isFetchingActivities: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getTicketsList(_state) {
    return _state.records;
  },
  getListMeta(_state) {
    return _state.listMeta;
  },
  getTicket: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getComments: _state => ticketId => {
    return _state.comments[ticketId] || [];
  },
  getActivities: _state => ticketId => {
    return _state.activities[ticketId] || [];
  },
};

export const actions = {
  fetchTickets: async ({ commit }, params = {}) => {
    commit(types.SET_TICKETS_UI_FLAG, { isFetchingList: true });
    try {
      const response = await TicketsAPI.get(params);
      const { payload, meta } = response.data;
      commit(types.SET_TICKETS_LIST, payload);
      commit(types.SET_TICKETS_LIST_META, meta);
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingList: false });
    }
  },
  fetchTicket: async ({ commit }, id) => {
    commit(types.SET_TICKETS_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await TicketsAPI.show(id);
      commit(types.SET_TICKET_ITEM, response.data);
      return response.data;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingItem: false });
    }
  },
  updateTicket: async ({ commit }, { id, ...data }) => {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.update(id, { ticket: data });
      commit(types.SET_TICKET_ITEM, response.data);
      return response.data;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },
  resolveTicket: async ({ commit }, id) => {
    const response = await TicketsAPI.resolve(id);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  reopenTicket: async ({ commit }, id) => {
    const response = await TicketsAPI.reopen(id);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  closeTicket: async ({ commit }, id) => {
    const response = await TicketsAPI.close(id);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  fetchComments: async ({ commit }, ticketId) => {
    commit(types.SET_TICKETS_UI_FLAG, { isFetchingComments: true });
    try {
      const response = await TicketsAPI.getComments(ticketId);
      commit(types.SET_TICKET_COMMENTS, { ticketId, comments: response.data });
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingComments: false });
    }
  },
  createComment: async ({ commit }, { ticketId, content }) => {
    commit(types.SET_TICKETS_UI_FLAG, { isCreatingComment: true });
    try {
      const response = await TicketsAPI.createComment(ticketId, content);
      commit(types.ADD_TICKET_COMMENT, { ticketId, comment: response.data });
      return response.data;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isCreatingComment: false });
    }
  },
  deleteComment: async ({ commit }, { ticketId, commentId }) => {
    await TicketsAPI.deleteComment(ticketId, commentId);
    commit(types.REMOVE_TICKET_COMMENT, { ticketId, commentId });
  },
  fetchActivities: async ({ commit }, ticketId) => {
    commit(types.SET_TICKETS_UI_FLAG, { isFetchingActivities: true });
    try {
      const response = await TicketsAPI.getActivities(ticketId);
      commit(types.SET_TICKET_ACTIVITIES, { ticketId, activities: response.data });
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingActivities: false });
    }
  },
  // Applied when a `ticket.*` realtime event arrives (see actionCable.js),
  // so open tabs/other agents see Kanban/Lista changes without a refetch.
  upsertFromRealtime: ({ commit }, ticket) => {
    commit(types.SET_TICKET_ITEM, ticket);
  },
  removeFromRealtime: ({ commit }, ticketId) => {
    commit(types.REMOVE_TICKET_ITEM, ticketId);
  },
};

export const mutations = {
  [types.SET_TICKETS_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_TICKETS_LIST](_state, tickets) {
    _state.records = tickets;
  },
  [types.SET_TICKETS_LIST_META](_state, meta) {
    _state.listMeta = {
      count: meta?.count || 0,
      currentPage: meta?.current_page || 1,
    };
  },
  [types.SET_TICKET_ITEM](_state, ticket) {
    const index = _state.records.findIndex(record => record.id === ticket.id);
    if (index === -1) {
      _state.records.push(ticket);
    } else {
      _state.records.splice(index, 1, ticket);
    }
  },
  [types.REMOVE_TICKET_ITEM](_state, ticketId) {
    _state.records = _state.records.filter(record => record.id !== ticketId);
  },
  [types.SET_TICKET_COMMENTS](_state, { ticketId, comments }) {
    _state.comments = { ..._state.comments, [ticketId]: comments };
  },
  [types.ADD_TICKET_COMMENT](_state, { ticketId, comment }) {
    const existing = _state.comments[ticketId] || [];
    _state.comments = {
      ..._state.comments,
      [ticketId]: [...existing, comment],
    };
  },
  [types.REMOVE_TICKET_COMMENT](_state, { ticketId, commentId }) {
    const existing = _state.comments[ticketId] || [];
    _state.comments = {
      ..._state.comments,
      [ticketId]: existing.filter(comment => comment.id !== commentId),
    };
  },
  [types.SET_TICKET_ACTIVITIES](_state, { ticketId, activities }) {
    _state.activities = { ..._state.activities, [ticketId]: activities };
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
