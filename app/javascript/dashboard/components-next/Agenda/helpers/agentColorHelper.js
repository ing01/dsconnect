import { EVENT_COLOR_OPTIONS, DEFAULT_EVENT_COLOR } from '../constants';

// Every agent gets one consistent color across the whole agenda (derived
// from their id), instead of each event picking its own color - so at a
// glance you can tell whose event is whose, even across teams/views.
export const colorForAgent = agentId => {
  if (!agentId) return DEFAULT_EVENT_COLOR;
  const index = Number(agentId) % EVENT_COLOR_OPTIONS.length;
  return EVENT_COLOR_OPTIONS[index];
};

// The color an event should render with - keyed off whoever created it,
// since that's the one single-valued "owner" every event always has
// (attendees can be empty or many).
export const colorForEvent = event => colorForAgent(event.created_by_id);
