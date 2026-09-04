import TicketTimeEntriesAPI from '../../api/ticketTimeEntries';

// Keyed by ticket, same shape as ticketChecklistItems - only ever looked at
// from the ticket's own detail page.
export const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getEntriesByTicket: _state => ticketId => {
    return _state.records[ticketId] || [];
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  getByTicket: async ({ commit }, ticketId) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await TicketTimeEntriesAPI.getEntries(ticketId);
      commit('SET_ENTRIES', { ticketId, entries: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  create: async ({ commit }, { ticketId, ...data }) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await TicketTimeEntriesAPI.createEntry(ticketId, data);
      commit('ADD_ENTRY', { ticketId, entry: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  update: async ({ commit }, { ticketId, entryId, ...data }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await TicketTimeEntriesAPI.updateEntry(ticketId, entryId, data);
      commit('UPDATE_ENTRY', { ticketId, entry: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  delete: async ({ commit }, { ticketId, entryId }) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await TicketTimeEntriesAPI.deleteEntry(ticketId, entryId);
      commit('REMOVE_ENTRY', { ticketId, entryId });
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_ENTRIES(_state, { ticketId, entries }) {
    _state.records = { ..._state.records, [ticketId]: entries };
  },
  ADD_ENTRY(_state, { ticketId, entry }) {
    const existing = _state.records[ticketId] || [];
    _state.records = { ..._state.records, [ticketId]: [entry, ...existing] };
  },
  UPDATE_ENTRY(_state, { ticketId, entry }) {
    const existing = _state.records[ticketId] || [];
    const index = existing.findIndex(record => record.id === entry.id);
    const updated =
      index === -1
        ? [entry, ...existing]
        : [...existing.slice(0, index), entry, ...existing.slice(index + 1)];
    _state.records = { ..._state.records, [ticketId]: updated };
  },
  REMOVE_ENTRY(_state, { ticketId, entryId }) {
    const existing = _state.records[ticketId] || [];
    _state.records = {
      ..._state.records,
      [ticketId]: existing.filter(record => record.id !== entryId),
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
