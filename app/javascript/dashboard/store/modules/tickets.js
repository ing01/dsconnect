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
  attachments: {},
  uiFlags: {
    isFetchingList: false,
    isFetchingItem: false,
    isUpdating: false,
    isFetchingComments: false,
    isCreating: false,
    isCreatingComment: false,
    isFetchingActivities: false,
    isFetchingAttachments: false,
    isUploadingAttachment: false,
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
  getAttachments: _state => ticketId => {
    return _state.attachments[ticketId] || [];
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
  // The single creation path behind the Kanban, the chat and the child flow.
  // Files are uploaded afterwards on purpose: a TicketAttachment belongs to a
  // ticket, so there is nothing to attach them to until it exists.
  createTicketWithContext: async (
    { commit, dispatch },
    {
      ticket,
      files = [],
      conversationId = null,
      parentId = null,
      options = null,
    }
  ) => {
    commit(types.SET_TICKETS_UI_FLAG, { isCreating: true });
    try {
      const response = parentId
        ? await TicketsAPI.createChild(parentId, { options, ticket })
        : await TicketsAPI.createTicket({ ticket, conversationId });
      const created = response.data;

      if (files.length) {
        await dispatch('uploadTicketFiles', { ticketId: created.id, files });
      }

      commit(types.SET_TICKET_ITEM, created);
      return created;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isCreating: false });
    }
  },
  // Sequential rather than parallel: the endpoint takes one multipart file per
  // request, and a burst of them is what trips the upload size guards.
  uploadTicketFiles: async (_context, { ticketId, files }) => {
    // eslint-disable-next-line no-restricted-syntax
    for (const file of files) {
      // eslint-disable-next-line no-await-in-loop
      await TicketsAPI.createAttachment(ticketId, file);
    }
  },
  classifyTicket: async ({ commit }, { id, ...classification }) => {
    const response = await TicketsAPI.classify(id, classification);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  // Rejects when the message did not actually leave, so the caller can keep the
  // ticket open. The ticket is refetched because `missing_close_requirements`
  // changes with it.
  sendCustomerCommunication: async ({ dispatch }, { ticketId, ...message }) => {
    await TicketsAPI.sendCustomerCommunication(ticketId, message);
    return dispatch('fetchTicket', ticketId);
  },
  cancelTicket: async ({ commit }, { id, reason }) => {
    const response = await TicketsAPI.cancel(id, reason);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  // Every composite action below returns the full detail payload of the ticket
  // it affected, so the store is updated from the response instead of guessing
  // what changed.
  transferTicket: async ({ commit }, { id, ...ticket }) => {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.transfer(id, ticket);
      commit(types.SET_TICKET_ITEM, response.data);
      return response.data;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },
  // Returns the CHILD, which is a different ticket from the one in view - the
  // caller navigates to it. The parent is refetched separately so its own
  // `children` list is current.
  createChildTicket: async ({ commit, dispatch }, { id, options, ticket }) => {
    const response = await TicketsAPI.createChild(id, { options, ticket });
    commit(types.SET_TICKET_ITEM, response.data);
    await dispatch('fetchTicket', id);
    return response.data;
  },
  setTicketParent: async ({ commit }, { id, parentId }) => {
    const response = await TicketsAPI.setParent(id, parentId);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  // `id` survives; `sourceId` is closed into it. Both are refreshed: the source
  // is now closed and its Kanban card must reflect that.
  mergeTicket: async ({ commit, dispatch }, { id, sourceId }) => {
    const response = await TicketsAPI.merge(id, sourceId);
    commit(types.SET_TICKET_ITEM, response.data);
    await dispatch('fetchTicket', sourceId);
    return response.data;
  },
  duplicateTicket: async ({ commit }, id) => {
    const response = await TicketsAPI.duplicate(id);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  assignTicketToMe: async ({ commit }, id) => {
    const response = await TicketsAPI.assignToMe(id);
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  adjustTicketSla: async (
    { commit },
    { id, hours, dueAt, reason, slaKind }
  ) => {
    const response = await TicketsAPI.adjustSla(id, {
      hours,
      dueAt,
      reason,
      slaKind,
    });
    commit(types.SET_TICKET_ITEM, response.data);
    return response.data;
  },
  addTicketFollower: async ({ dispatch }, { ticketId, userId }) => {
    await TicketsAPI.addFollower(ticketId, userId);
    return dispatch('fetchTicket', ticketId);
  },
  removeTicketFollower: async ({ dispatch }, { ticketId, followerId }) => {
    await TicketsAPI.removeFollower(ticketId, followerId);
    return dispatch('fetchTicket', ticketId);
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
      commit(types.SET_TICKET_ACTIVITIES, {
        ticketId,
        activities: response.data,
      });
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingActivities: false });
    }
  },
  // Applied when a `ticket.*` realtime event arrives (see actionCable.js),
  // so open tabs/other agents see Kanban/Lista changes without a refetch.
  // Stage changes must go through `move`, not `update`: TicketsController#update
  // strips `ticket_column_id`, and only `move` keeps `team_id` in lockstep and
  // reindexes both columns. Omitting `position` lets the server slot the ticket
  // into the destination by ticket number.
  moveTicket: async ({ commit }, { id, ticketColumnId, position }) => {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.move(id, { ticketColumnId, position });
      commit(types.SET_TICKET_ITEM, response.data);
      return response.data;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },
  fetchAttachments: async ({ commit }, ticketId) => {
    commit(types.SET_TICKETS_UI_FLAG, { isFetchingAttachments: true });
    try {
      const response = await TicketsAPI.getAttachments(ticketId);
      commit(types.SET_TICKET_ATTACHMENTS, {
        ticketId,
        attachments: response.data,
      });
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingAttachments: false });
    }
  },
  createAttachment: async ({ commit }, { ticketId, file }) => {
    commit(types.SET_TICKETS_UI_FLAG, { isUploadingAttachment: true });
    try {
      const response = await TicketsAPI.createAttachment(ticketId, file);
      commit(types.ADD_TICKET_ATTACHMENT, {
        ticketId,
        attachment: response.data,
      });
      return response.data;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUploadingAttachment: false });
    }
  },
  deleteAttachment: async ({ commit }, { ticketId, attachmentId }) => {
    await TicketsAPI.deleteAttachment(ticketId, attachmentId);
    commit(types.REMOVE_TICKET_ATTACHMENT, { ticketId, attachmentId });
  },
  upsertFromRealtime: ({ commit }, ticket) => {
    commit(types.UPDATE_TICKET_FROM_REALTIME, ticket);
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
  // Merges rather than replaces. Realtime payloads (`Ticket#push_event_data`)
  // are narrower than the REST ones - no `assignee_name`, no `team_name`, none
  // of the detail-only blocks - so replacing would blank the detail page on the
  // first event to arrive. Every field an event does carry is sent explicitly,
  // including nulls, so a merge never keeps a stale value.
  [types.SET_TICKET_ITEM](_state, ticket) {
    const index = _state.records.findIndex(record => record.id === ticket.id);
    if (index === -1) {
      _state.records.push(ticket);
    } else {
      _state.records.splice(index, 1, { ..._state.records[index], ...ticket });
    }
  },
  [types.SET_TICKET_ATTACHMENTS](_state, { ticketId, attachments }) {
    _state.attachments = { ..._state.attachments, [ticketId]: attachments };
  },
  [types.ADD_TICKET_ATTACHMENT](_state, { ticketId, attachment }) {
    const current = _state.attachments[ticketId] || [];
    _state.attachments = {
      ..._state.attachments,
      [ticketId]: [attachment, ...current],
    };
  },
  [types.REMOVE_TICKET_ATTACHMENT](_state, { ticketId, attachmentId }) {
    const current = _state.attachments[ticketId] || [];
    _state.attachments = {
      ..._state.attachments,
      [ticketId]: current.filter(attachment => attachment.id !== attachmentId),
    };
  },
  // Diferente do SET_TICKET_ITEM: aqui um ticket desconhecido e ignorado em vez
  // de entrar na lista. `records` e o resultado da Busca detalhada, e empurrar
  // para dentro dele um ticket que o filtro nao pediu mostraria uma linha que
  // nao pertence aquele resultado - e ainda desencontraria a contagem da
  // paginacao. Quem mostra ticket novo em tempo real e o Kanban.
  [types.UPDATE_TICKET_FROM_REALTIME](_state, ticket) {
    const index = _state.records.findIndex(record => record.id === ticket.id);
    if (index === -1) return;

    _state.records.splice(index, 1, { ..._state.records[index], ...ticket });
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
