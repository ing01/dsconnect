import { computed, reactive } from 'vue';
import TicketsAPI from 'dashboard/api/tickets';
import {
  neighbourTabId,
  readWorkspaceTabs,
  writeWorkspaceTabs,
} from '../helpers/ticketWorkspaceTabs';

// The open-Tickets workspace: a navigation layer, not a second copy of the
// Ticket. A tab holds an id plus the few strings its label needs, and the
// content of the active tab is the real detail page the router already renders.
//
// The state sits at module scope on purpose. The bar unmounts whenever the user
// leaves the Tickets module, and re-reading localStorage on the way back would
// re-run the whole restore just to rebuild what memory already had.
const state = reactive({
  scope: null,
  tabs: [],
  activeId: null,
});

// The label snapshot. It is kept here rather than read live from the tickets
// store because that store's `records` is also the Busca detalhada result list
// and is replaced wholesale on every search - the labels of open tabs would
// blank out the moment someone ran one.
const LABEL_FIELDS = {
  displayId: 'display_id',
  company: 'company_name',
  title: 'title',
  requester: 'requester_name',
};

const emptyTab = id => ({
  id: Number(id),
  displayId: null,
  company: '',
  title: '',
  requester: '',
});

// Only the fields the payload actually carries are written. Realtime events are
// narrower than the REST ones, so overwriting blindly would blank the Empresa
// out of a label the moment any event arrived.
const mergeLabel = (tab, ticket) =>
  Object.entries(LABEL_FIELDS).reduce(
    (merged, [key, field]) =>
      field in ticket
        ? { ...merged, [key]: ticket[field] ?? emptyTab(tab.id)[key] }
        : merged,
    { ...tab }
  );

const toTab = ticket => mergeLabel(emptyTab(ticket.id), ticket);

const ticketIds = () => state.tabs.map(tab => tab.id);

const persist = () => {
  if (!state.scope) return;
  const [accountId, userId] = state.scope;
  writeWorkspaceTabs(accountId, userId, {
    ticketIds: ticketIds(),
    activeTicketId: state.activeId,
  });
};

const removeTab = id => {
  state.tabs = state.tabs.filter(tab => tab.id !== Number(id));
};

// Restores one persisted id. The fetch is what re-validates access: a Ticket the
// user can no longer open (moved Mesa, revoked role, deleted) answers 403/404
// and its tab is dropped instead of sitting there as a dead link.
const restoreTab = async id => {
  try {
    const { data } = await TicketsAPI.show(id);
    const index = state.tabs.findIndex(tab => tab.id === Number(id));
    if (index !== -1) state.tabs.splice(index, 1, toTab(data));
  } catch (error) {
    removeTab(id);
  }
};

export function useTicketWorkspace() {
  const tabs = computed(() => state.tabs);
  const activeId = computed(() => state.activeId);
  const hasTabs = computed(() => state.tabs.length > 0);

  // Hydrates from localStorage the first time this (account, user) is seen.
  const restore = async (accountId, userId) => {
    const scope = [Number(accountId), Number(userId)];
    if (state.scope?.[0] === scope[0] && state.scope?.[1] === scope[1]) return;

    state.scope = scope;
    const stored = readWorkspaceTabs(accountId, userId);
    state.tabs = stored.ticketIds.map(emptyTab);
    state.activeId = stored.activeTicketId;

    await Promise.all(stored.ticketIds.map(restoreTab));

    // A tab that failed re-validation may have been the active one.
    if (!ticketIds().includes(state.activeId)) state.activeId = null;
    persist();
  };

  // Opening an already-open Ticket activates its tab instead of adding a second
  // one - the bar is keyed by Ticket id, so duplicates cannot occur.
  const openTab = ticket => {
    const id = Number(ticket?.id ?? ticket);
    if (!Number.isFinite(id)) return;

    const index = state.tabs.findIndex(tab => tab.id === id);
    if (index === -1) {
      state.tabs.push(
        typeof ticket === 'object' ? toTab(ticket) : emptyTab(id)
      );
    }
    state.activeId = id;
    persist();
  };

  // Closing a tab is a view action and nothing more: no status change, no
  // request, no trace on the Ticket. Returns the tab to activate next, or null
  // when the bar is now empty and the caller should fall back to the Kanban.
  const closeTab = id => {
    const next = neighbourTabId(ticketIds(), id);
    const wasActive = state.activeId === Number(id);

    removeTab(id);
    if (wasActive) state.activeId = next;
    persist();

    return wasActive ? next : state.activeId;
  };

  // Keeps the label honest while the Ticket is edited: renaming it or moving it
  // to another Empresa rewrites the tab in place, with no refresh.
  const applyTicket = ticket => {
    if (!ticket?.id) return;
    const index = state.tabs.findIndex(tab => tab.id === Number(ticket.id));
    if (index === -1) return;

    const current = state.tabs[index];
    const next = mergeLabel(current, ticket);
    const changed = Object.keys(next).some(key => next[key] !== current[key]);
    if (changed) state.tabs.splice(index, 1, next);
  };

  return {
    tabs,
    activeId,
    hasTabs,
    restore,
    openTab,
    closeTab,
    applyTicket,
  };
}
