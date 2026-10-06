import {
  SET_CALENDAR_EVENT_UI_FLAG,
  SET_CALENDAR_EVENTS,
  ADD_CALENDAR_EVENT,
  EDIT_CALENDAR_EVENT,
  DELETE_CALENDAR_EVENT,
  SET_CALENDAR_EVENTS_BY_TICKET,
} from './types';
import CalendarEventsAPI from '../../../api/calendarEvents';

export const actions = {
  get: async ({ commit }, { teamId, since, until }) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isFetching: true });
    try {
      const { data } = await CalendarEventsAPI.get({ teamId, since, until });
      commit(SET_CALENDAR_EVENTS, { teamId, events: data.payload });
      return data.payload;
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isFetching: false });
    }
  },

  getByTicket: async ({ commit }, { ticketId }) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isFetching: true });
    try {
      const { data } = await CalendarEventsAPI.get({ ticketId });
      commit(SET_CALENDAR_EVENTS_BY_TICKET, { ticketId, events: data.payload });
      return data.payload;
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, eventData) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isCreating: true });
    try {
      const { data } = await CalendarEventsAPI.create(eventData);
      commit(ADD_CALENDAR_EVENT, data);
      return data;
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, scope, occurrenceDate, ...eventData }) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await CalendarEventsAPI.update(id, {
        scope,
        occurrenceDate,
        ...eventData,
      });
      // Com `scope`, a resposta pode ser uma serie NOVA (id diferente) ou
      // uma ocorrencia virou substituta - um commit por id so' faz sentido
      // no caminho sem escopo; quem despachou com `scope` e' quem recarrega
      // a janela visivel (ver `AgendaPage.vue`).
      if (!scope) commit(EDIT_CALENDAR_EVENT, data);
      return data;
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, { id, teamId, scope, occurrenceDate }) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isDeleting: true });
    try {
      await CalendarEventsAPI.delete(id, { scope, occurrenceDate });
      if (!scope) commit(DELETE_CALENDAR_EVENT, { id, teamId });
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isDeleting: false });
    }
  },
};
