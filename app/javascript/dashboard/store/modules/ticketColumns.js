import types from '../mutation-types';
import TeamsAPI from '../../api/teams';
import TicketColumnsAPI from '../../api/ticketColumns';
import TicketCategoriesAPI from '../../api/ticketCategories';
import TicketSlaPoliciesAPI from '../../api/ticketSlaPolicies';
import TicketsAPI from '../../api/tickets';

// The Kanban is the operational board: only tickets still being worked on. A
// resolved, closed or cancelled ticket leaves it - it is not deleted, and the
// "Busca detalhada" still finds it. Reopening one puts it back.
const isOperational = ticket => ticket.status === 'open';

// Holds the Kanban ("board") view of a single Mesa de Servico (Team): the
// Team plus its Estagios (ticket_columns), each with the tickets currently
// sitting in it. Keyed by team_id so multiple Mesas can be cached at once.
// Team CRUD itself (name/description/members) stays in `store/modules/teams`
// - this module only owns the ticket-Kanban slice of a Team.
export const state = {
  records: {},
  // Lean Estagio lists keyed by team, for callers that need the stages without
  // the board's inlined tickets (the Ticket detail page's stage select).
  columnsByTeam: {},
  // Categories are scoped to a Mesa the same way Estagios are, and the creation
  // form needs both lists the moment a Mesa is chosen.
  categoriesByTeam: {},
  // A matriz Mesa x Prioridade e o expediente, que sao configuracao da mesma
  // Mesa que os Estagios e as Categorias - por isso vivem neste modulo.
  slaPoliciesByTeam: {},
  workingHoursByTeam: {},
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
  getColumns: _state => teamId => {
    return _state.columnsByTeam[teamId] || [];
  },
  getSlaPolicies: _state => teamId => {
    return _state.slaPoliciesByTeam[teamId] || [];
  },
  getWorkingHours: _state => teamId => {
    return _state.workingHoursByTeam[teamId] || null;
  },
  getCategories: _state => teamId => {
    return _state.categoriesByTeam[teamId] || [];
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
  fetchColumns: async ({ commit }, teamId) => {
    if (!teamId) return [];

    const response = await TicketColumnsAPI.get(teamId);
    commit(types.SET_TICKET_COLUMNS_BY_TEAM, {
      teamId,
      columns: response.data,
    });
    return response.data;
  },
  fetchCategories: async ({ commit }, teamId) => {
    if (!teamId) return [];

    const response = await TicketCategoriesAPI.get(teamId);
    commit(types.SET_TICKET_CATEGORIES_BY_TEAM, {
      teamId,
      categories: response.data,
    });
    return response.data;
  },
  createCategory: async ({ dispatch }, { teamId, ...data }) => {
    await TicketCategoriesAPI.create(teamId, data);
    return dispatch('fetchCategories', teamId);
  },
  updateCategory: async ({ dispatch }, { teamId, categoryId, ...data }) => {
    await TicketCategoriesAPI.update(teamId, categoryId, data);
    return dispatch('fetchCategories', teamId);
  },
  deleteCategory: async ({ dispatch }, { teamId, categoryId }) => {
    await TicketCategoriesAPI.delete(teamId, categoryId);
    return dispatch('fetchCategories', teamId);
  },

  fetchSlaPolicies: async ({ commit }, teamId) => {
    if (!teamId) return;

    const response = await TicketSlaPoliciesAPI.get(teamId);
    commit(types.SET_TICKET_SLA_POLICIES_BY_TEAM, {
      teamId,
      policies: response.data.payload,
    });
  },
  // Uma prioridade sem linha na matriz simplesmente nao tem prazo; por isso
  // criar e atualizar sao acoes distintas, e apagar e como se zera um prazo.
  createSlaPolicy: async ({ dispatch }, { teamId, ...data }) => {
    await TicketSlaPoliciesAPI.create(teamId, data);
    return dispatch('fetchSlaPolicies', teamId);
  },
  updateSlaPolicy: async ({ dispatch }, { teamId, policyId, ...data }) => {
    await TicketSlaPoliciesAPI.update(teamId, policyId, data);
    return dispatch('fetchSlaPolicies', teamId);
  },
  deleteSlaPolicy: async ({ dispatch }, { teamId, policyId }) => {
    await TicketSlaPoliciesAPI.delete(teamId, policyId);
    return dispatch('fetchSlaPolicies', teamId);
  },

  fetchWorkingHours: async ({ commit }, teamId) => {
    if (!teamId) return;

    const response = await TicketSlaPoliciesAPI.getWorkingHours(teamId);
    commit(types.SET_TEAM_WORKING_HOURS, { teamId, workingHours: response.data });
  },
  updateWorkingHours: async ({ commit }, { teamId, ...data }) => {
    const response = await TicketSlaPoliciesAPI.updateWorkingHours(teamId, data);
    commit(types.SET_TEAM_WORKING_HOURS, { teamId, workingHours: response.data });
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
  // Estas cinco atualizam o quadro pelo MESMO caminho que o tempo real ja usa
  // para refletir a acao de outro agente (`UPSERT_TICKET_IN_KANBAN_BOARD`) -
  // o endpoint ja devolve o ticket com o formato completo do board (via
  // `_ticket_detail`, que comeca justamente pelo partial `_ticket`). Antes,
  // cada uma recarregava o quadro INTEIRO (todas as colunas, ate 300 tickets
  // cada) so para refletir a mudanca de UM ticket - um arrastar-e-soltar no
  // Kanban virava a chamada mais pesada da tela, repetida a cada carta movida.
  createTicket: async ({ commit }, { teamId, ...data }) => {
    const response = await TicketsAPI.create({ team_id: teamId, ...data });
    commit(types.UPSERT_TICKET_IN_KANBAN_BOARD, response.data);
    return response.data;
  },
  updateTicket: async ({ commit }, { id, ...data }) => {
    const response = await TicketsAPI.update(id, { ticket: data });
    commit(types.UPSERT_TICKET_IN_KANBAN_BOARD, response.data);
    return response.data;
  },
  // Reindexa os IRMAOS de coluna no servidor (posicoes 0,1,2...), mas nao
  // devolve-os - so o cartao movido. O proprio arrastar-e-soltar ja reflete a
  // ordem na tela sem depender disso; a `position` exata dos outros cartoes
  // so fica desatualizada no estado local ate o quadro recarregar por outro
  // motivo, o que nunca chega a ficar visivel.
  moveTicket: async ({ commit }, { id, ticketColumnId, position }) => {
    const response = await TicketsAPI.move(id, { ticketColumnId, position });
    commit(types.UPSERT_TICKET_IN_KANBAN_BOARD, response.data);
    return response.data;
  },
  deleteTicket: async ({ commit }, { id }) => {
    await TicketsAPI.delete(id);
    commit(types.REMOVE_TICKET_FROM_KANBAN_BOARD, id);
  },
  linkConversation: async ({ commit }, { ticketId, conversationId }) => {
    const response = await TicketsAPI.linkConversation(
      ticketId,
      conversationId
    );
    commit(types.UPSERT_TICKET_IN_KANBAN_BOARD, response.data);
    return response.data;
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
  [types.SET_TICKET_COLUMNS_BY_TEAM](_state, { teamId, columns }) {
    _state.columnsByTeam = { ..._state.columnsByTeam, [teamId]: columns };
  },
  [types.SET_TICKET_SLA_POLICIES_BY_TEAM](_state, { teamId, policies }) {
    _state.slaPoliciesByTeam = {
      ..._state.slaPoliciesByTeam,
      [teamId]: policies,
    };
  },
  [types.SET_TEAM_WORKING_HOURS](_state, { teamId, workingHours }) {
    _state.workingHoursByTeam = {
      ..._state.workingHoursByTeam,
      [teamId]: workingHours,
    };
  },
  [types.SET_TICKET_CATEGORIES_BY_TEAM](_state, { teamId, categories }) {
    _state.categoriesByTeam = {
      ..._state.categoriesByTeam,
      [teamId]: categories,
    };
  },
  [types.SET_TICKET_KANBAN_BOARD](_state, board) {
    _state.records = {
      ..._state.records,
      [board.id]: board,
    };
  },
  [types.UPSERT_TICKET_IN_KANBAN_BOARD](_state, ticket) {
    // A ticket that just reached a terminal state is removed rather than
    // upserted, so closing/resolving/cancelling drops the card (and the column
    // counter, which is derived from this list) without a refetch, here and on
    // every other agent's board over realtime.
    if (!isOperational(ticket)) {
      Object.values(_state.records).forEach(board => {
        (board.ticket_columns || []).forEach(column => {
          column.tickets = (column.tickets || []).filter(
            t => t.id !== ticket.id
          );
        });
      });
      return;
    }

    Object.values(_state.records).forEach(board => {
      let targetColumn = null;
      (board.ticket_columns || []).forEach(column => {
        if (column.id === ticket.ticket_column_id) targetColumn = column;

        const tickets = column.tickets || [];
        const index = tickets.findIndex(t => t.id === ticket.id);
        if (index === -1) return;

        if (column.id === ticket.ticket_column_id) {
          // Mescla, nao substitui: o payload de tempo real e mais estreito que
          // o do quadro, entao trocar o objeto inteiro apagaria do card os
          // campos que so a carga inicial traz.
          column.tickets = [
            ...tickets.slice(0, index),
            { ...tickets[index], ...ticket },
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
        column.tickets = (column.tickets || []).filter(t => t.id !== ticketId);
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
