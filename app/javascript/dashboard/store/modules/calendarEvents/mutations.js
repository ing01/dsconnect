import {
  SET_CALENDAR_EVENT_UI_FLAG,
  SET_CALENDAR_EVENTS,
  ADD_CALENDAR_EVENT,
  EDIT_CALENDAR_EVENT,
  DELETE_CALENDAR_EVENT,
} from './types';

export const mutations = {
  [SET_CALENDAR_EVENT_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  [SET_CALENDAR_EVENTS]($state, { teamId, events }) {
    $state.records = {
      ...$state.records,
      [teamId]: events,
    };
  },

  [ADD_CALENDAR_EVENT]($state, event) {
    const existing = $state.records[event.team_id] || [];
    $state.records = {
      ...$state.records,
      [event.team_id]: [...existing, event],
    };
  },

  [EDIT_CALENDAR_EVENT]($state, event) {
    const existing = $state.records[event.team_id] || [];
    const index = existing.findIndex(record => record.id === event.id);
    const updated = index === -1 ? [...existing, event] : [
      ...existing.slice(0, index),
      event,
      ...existing.slice(index + 1),
    ];
    $state.records = {
      ...$state.records,
      [event.team_id]: updated,
    };
  },

  [DELETE_CALENDAR_EVENT]($state, { teamId, id }) {
    const existing = $state.records[teamId] || [];
    $state.records = {
      ...$state.records,
      [teamId]: existing.filter(record => record.id !== id),
    };
  },
};
