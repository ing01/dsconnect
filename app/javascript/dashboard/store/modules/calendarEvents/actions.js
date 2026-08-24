import {
  SET_CALENDAR_EVENT_UI_FLAG,
  SET_CALENDAR_EVENTS,
  ADD_CALENDAR_EVENT,
  EDIT_CALENDAR_EVENT,
  DELETE_CALENDAR_EVENT,
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

  update: async ({ commit }, { id, ...eventData }) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await CalendarEventsAPI.update(id, eventData);
      commit(EDIT_CALENDAR_EVENT, data);
      return data;
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, { id, teamId }) => {
    commit(SET_CALENDAR_EVENT_UI_FLAG, { isDeleting: true });
    try {
      await CalendarEventsAPI.delete(id);
      commit(DELETE_CALENDAR_EVENT, { id, teamId });
    } finally {
      commit(SET_CALENDAR_EVENT_UI_FLAG, { isDeleting: false });
    }
  },
};
