import store from 'dashboard/store';
import { EVENT_COLOR_OPTIONS, DEFAULT_EVENT_COLOR } from '../constants';

const HEX_COLOR = /^#[0-9a-f]{6}$/i;

// The color the agent chose in their profile settings (stored in the user's
// custom attributes and shared with everyone through the agents list).
export const chosenColorOf = agentId => {
  const agents = store.getters['agents/getAgents'] || [];
  const agent = agents.find(item => Number(item.id) === Number(agentId));
  const color = agent?.custom_attributes?.agenda_color;
  return HEX_COLOR.test(color || '') ? color : null;
};

// Every agent gets one consistent color across the whole agenda, instead of
// each event picking its own color - so at a glance you can tell whose event
// is whose, even across teams/views. It is the color the agent chose in their
// profile, or else one derived from their id.
export const colorForAgent = agentId => {
  if (!agentId) return DEFAULT_EVENT_COLOR;
  const chosen = chosenColorOf(agentId);
  if (chosen) return chosen;
  const index = Number(agentId) % EVENT_COLOR_OPTIONS.length;
  return EVENT_COLOR_OPTIONS[index];
};

// The color an event should render with - keyed off whoever created it,
// since that's the one single-valued "owner" every event always has
// (attendees can be empty or many).
export const colorForEvent = event => colorForAgent(event.created_by_id);
