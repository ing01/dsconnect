import types from '../mutation-types';
import TeamsAPI from '../../api/teams';
import TicketColumnsAPI from '../../api/ticketColumns';
import TicketsAPI from '../../api/tickets';

// Holds the Kanban ("board") view of a single Mesa de Servico (Team): the
// Team plus its Estagios (ticket_columns), each with the tickets currently
// sitting in it. Keyed by team_id so multiple Mesas can be cached at once.
// Team CRUD itself (name/description/members) stays in `store/modules/teams`
// - this module only owns the ticket-Kanban slice of a Team.
export const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getBoard: _state => teamId => {
    return _state.records[teamId] || null;
  },
};

export const actions = {
  fetchBoard: async ({ commit }, teamId) => {
    commit(types.SET_TICKET_KANBAN_UI_FLAG, { isFetching: true });
    try {
      const response = await TeamsAPI.show(teamId);
      commit(types.SET_TICKET_KANBAN_BOARD, response.data);
      return response.data;
    } finally {
      commit(types.SET_TICKET_KANBAN_UI_FLAG, { isFetching: false });
    }
  },
  createColumn: async ({ dispatch }, { teamId, ...data }) => {
    await TicketColumnsAPI.create(teamId, data);
    await dispatch('fetchBoard', teamId);
  },
  updateColumn: async ({ dispatch }, { teamId, columnId, ...data }) => {
    await TicketColumnsAPI.update(teamId, columnId, data);
    await dispatch('fetchBoard', teamId);
    // Handing an Estagio to another Mesa leaves the destination board stale too.
    if (data.team_id && Number(data.team_id) !== Number(teamId)) {
      await dispatch('fetchBoard', Number(data.team_id));
    }
  },
  deleteColumn: async ({ dispatch }, { teamId, columnId }) => {
    await TicketColumnsAPI.delete(teamId, columnId);
    await dispatch('fetchBoard', teamId);
  },
  reorderColumns: async ({ commit }, { teamId, columnIds }) => {
    const response = await TicketColumnsAPI.reorder(teamId, columnIds);
    commit(types.SET_TICKET_KANBAN_BOARD, response.data);
  },
  createTicket: async ({ dispatch }, { teamId, ...data }) => {
    await TicketsAPI.create({ team_id: teamId, ...data });
    await dispatch('fetchBoard', teamId);
  },
  updateTicket: async ({ dispatch }, { teamId, id, ...data }) => {
    await TicketsAPI.update(id, { ticket: data });
    await dispatch('fetchBoard', teamId);
  },
  moveTicket: async ({ dispatch }, { teamId, id, ticketColumnId, position }) => {
    await TicketsAPI.move(id, { ticketColumnId, position });
    await dispatch('fetchBoard', teamId);
  },
  deleteTicket: async ({ dispatch }, { teamId, id }) => {
    await TicketsAPI.delete(id);
    await dispatch('fetchBoard', teamId);
  },
  linkConversation: async ({ dispatch }, { teamId, ticketId, conversationId }) => {
    await TicketsAPI.linkConversation(ticketId, conversationId);
    await dispatch('fetchBoard', teamId);
  },
  unlinkConversation: async (
    { dispatch },
    { teamId, ticketId, conversationId }
  ) => {
    await TicketsAPI.unlinkConversation(ticketId, conversationId);
    await dispatch('fetchBoard', teamId);
  },
  // Applied when a `ticket.*` realtime event arrives (see actionCable.js),
  // so a Kanban board open in another tab/by another agent reflects
  // creates/moves/status changes without a full board refetch.
  applyRealtimeTicket: ({ commit }, ticket) => {
    commit(types.UPSERT_TICKET_IN_KANBAN_BOARD, ticket);
  },
  removeRealtimeTicket: ({ commit }, ticketId) => {
    commit(types.REMOVE_TICKET_FROM_KANBAN_BOARD, ticketId);
  },
  ensureDefaultMesa: async () => {
    const response = await TicketsAPI.ensureDefaultMesa();
    return response.data;
  },
};

export const mutations = {
  [types.SET_TICKET_KANBAN_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_TICKET_KANBAN_BOARD](_state, board) {
    _state.records = {
      ..._state.records,
      [board.id]: board,
    };
  },
  [types.UPSERT_TICKET_IN_KANBAN_BOARD](_state, ticket) {
    Object.values(_state.records).forEach(board => {
      let targetColumn = null;
      (board.ticket_columns || []).forEach(column => {
        if (column.id === ticket.ticket_column_id) targetColumn = column;

        const tickets = column.tickets || [];
        const index = tickets.findIndex(t => t.id === ticket.id);
        if (index === -1) return;

        if (column.id === ticket.ticket_column_id) {
          column.tickets = [
            ...tickets.slice(0, index),
            ticket,
            ...tickets.slice(index + 1),
          ];
        } else {
          column.tickets = tickets.filter(t => t.id !== ticket.id);
        }
      });

      if (
        targetColumn &&
        !(targetColumn.tickets || []).some(t => t.id === ticket.id)
      ) {
        targetColumn.tickets = [...(targetColumn.tickets || []), ticket];
      }
    });
  },
  [types.REMOVE_TICKET_FROM_KANBAN_BOARD](_state, ticketId) {
    Object.values(_state.records).forEach(board => {
      (board.ticket_columns || []).forEach(column => {
        column.tickets = (column.tickets || []).filter(
          t => t.id !== ticketId
        );
      });
    });
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
