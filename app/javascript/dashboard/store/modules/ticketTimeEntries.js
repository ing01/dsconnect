import TicketTimeEntriesAPI from '../../api/ticketTimeEntries';

// Keyed by ticket, same shape as ticketChecklistItems - only ever looked at
// from the ticket's own detail page.
export const state = {
  records: {},
  // Cronometros em andamento do proprio agente, por ticket. Cada um guarda o instante
  // em que a tela o recebeu (`receivedAt`): o relogio soma o que passou desde entao.
  timers: {},
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
  getTimersByTicket: _state => ticketId => {
    return _state.timers[ticketId] || [];
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
      const response = await TicketTimeEntriesAPI.updateEntry(
        ticketId,
        entryId,
        data
      );
      commit('UPDATE_ENTRY', { ticketId, entry: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
  getTimers: async ({ commit }, ticketId) => {
    const response = await TicketTimeEntriesAPI.getTimers(ticketId);
    commit('SET_TIMERS', { ticketId, timers: response.data });
    return response.data;
  },
  // Iniciar pausa, no servidor, o que estava correndo em outro ticket; o store
  // acompanha isso para nao mostrar dois relogios andando.
  startTimer: async ({ commit }, { ticketId, ...data }) => {
    const response = await TicketTimeEntriesAPI.startTimer(ticketId, data);
    commit('PAUSE_OTHER_TIMERS', { exceptTicketId: ticketId });
    commit('SET_TIMERS', { ticketId, timers: [response.data] });
    return response.data;
  },
  pauseTimer: async ({ commit }, { ticketId, timerId }) => {
    const response = await TicketTimeEntriesAPI.pauseTimer(ticketId, timerId);
    commit('SET_TIMERS', { ticketId, timers: [response.data] });
    return response.data;
  },
  resumeTimer: async ({ commit }, { ticketId, timerId }) => {
    const response = await TicketTimeEntriesAPI.resumeTimer(ticketId, timerId);
    commit('PAUSE_OTHER_TIMERS', { exceptTicketId: ticketId });
    commit('SET_TIMERS', { ticketId, timers: [response.data] });
    return response.data;
  },
  // Finalizar: o tempo vira um apontamento da lista e o cronometro some.
  finishTimer: async ({ commit }, { ticketId, timerId }) => {
    const response = await TicketTimeEntriesAPI.finishTimer(ticketId, timerId);
    commit('SET_TIMERS', { ticketId, timers: [] });
    commit('ADD_ENTRY', { ticketId, entry: response.data });
    return response.data;
  },
  discardTimer: async ({ commit }, { ticketId, timerId }) => {
    await TicketTimeEntriesAPI.discardTimer(ticketId, timerId);
    commit('SET_TIMERS', { ticketId, timers: [] });
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
  SET_TIMERS(_state, { ticketId, timers }) {
    const receivedAt = Date.now();
    _state.timers = {
      ..._state.timers,
      [ticketId]: timers.map(timer => ({ ...timer, receivedAt })),
    };
  },
  // Congela o que estava correndo nos outros tickets, com o tempo ja decorrido.
  PAUSE_OTHER_TIMERS(_state, { exceptTicketId }) {
    const now = Date.now();
    const next = {};
    Object.entries(_state.timers).forEach(([ticketId, list]) => {
      next[ticketId] =
        String(ticketId) === String(exceptTicketId)
          ? list
          : list.map(timer =>
              timer.status === 'running'
                ? {
                    ...timer,
                    status: 'paused',
                    elapsed_seconds:
                      timer.elapsed_seconds +
                      Math.max(0, (now - timer.receivedAt) / 1000),
                  }
                : timer
            );
    });
    _state.timers = next;
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
