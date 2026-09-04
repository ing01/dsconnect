import TicketChecklistItemsAPI from '../../api/ticketChecklistItems';

// Keyed by ticket, same shape as calendarEvents' ticketRecords - a ticket's
// checklist is only ever looked at from its own detail page.
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
  getItemsByTicket: _state => ticketId => {
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
      const response = await TicketChecklistItemsAPI.getItems(ticketId);
      commit('SET_ITEMS', { ticketId, items: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  create: async ({ commit }, { ticketId, title }) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await TicketChecklistItemsAPI.createItem(ticketId, {
        title,
      });
      commit('ADD_ITEM', { ticketId, item: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  toggle: async ({ commit }, { ticketId, itemId }) => {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await TicketChecklistItemsAPI.toggleItem(
        ticketId,
        itemId
      );
      commit('UPDATE_ITEM', { ticketId, item: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  delete: async ({ commit }, { ticketId, itemId }) => {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await TicketChecklistItemsAPI.deleteItem(ticketId, itemId);
      commit('REMOVE_ITEM', { ticketId, itemId });
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
  attachChecklist: async ({ commit }, { ticketId, checklistId }) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await TicketChecklistItemsAPI.attachChecklist(
        ticketId,
        checklistId
      );
      commit('ADD_ITEMS', { ticketId, items: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_ITEMS(_state, { ticketId, items }) {
    _state.records = { ..._state.records, [ticketId]: items };
  },
  ADD_ITEM(_state, { ticketId, item }) {
    const existing = _state.records[ticketId] || [];
    _state.records = { ..._state.records, [ticketId]: [...existing, item] };
  },
  ADD_ITEMS(_state, { ticketId, items }) {
    const existing = _state.records[ticketId] || [];
    _state.records = { ..._state.records, [ticketId]: [...existing, ...items] };
  },
  UPDATE_ITEM(_state, { ticketId, item }) {
    const existing = _state.records[ticketId] || [];
    const index = existing.findIndex(record => record.id === item.id);
    const updated =
      index === -1
        ? [...existing, item]
        : [
            ...existing.slice(0, index),
            item,
            ...existing.slice(index + 1),
          ];
    _state.records = { ..._state.records, [ticketId]: updated };
  },
  REMOVE_ITEM(_state, { ticketId, itemId }) {
    const existing = _state.records[ticketId] || [];
    _state.records = {
      ..._state.records,
      [ticketId]: existing.filter(record => record.id !== itemId),
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
