import { LocalStorage } from 'shared/helpers/localStorage';

// Which Tickets a user has open in the workspace bar is a per-viewer view
// preference, like the collapsed Estagios next door: it says nothing about the
// Ticket itself, so it lives in localStorage and never reaches the API.
//
// One entry per (account, user), because the same browser can hold sessions for
// different accounts and a tab list must not leak between them. Only ids and
// the active id are stored - never the Ticket's own data, which can go stale
// and which the viewer may have lost access to by the time they come back.
export const WORKSPACE_TABS_KEY_PREFIX = 'ticket-workspace-tabs';

export const workspaceTabsKey = (accountId, userId) =>
  `${WORKSPACE_TABS_KEY_PREFIX}::${accountId}::${userId}`;

const toIds = value =>
  Array.isArray(value) ? value.map(Number).filter(Number.isFinite) : [];

export const readWorkspaceTabs = (accountId, userId) => {
  const stored = LocalStorage.get(workspaceTabsKey(accountId, userId));
  const ticketIds = [...new Set(toIds(stored?.ticketIds))];
  const activeTicketId = Number(stored?.activeTicketId);

  return {
    ticketIds,
    // An active id that is not in the list would activate a tab that does not
    // exist, so it is dropped rather than trusted.
    activeTicketId: ticketIds.includes(activeTicketId) ? activeTicketId : null,
  };
};

export const writeWorkspaceTabs = (
  accountId,
  userId,
  { ticketIds, activeTicketId }
) =>
  LocalStorage.set(workspaceTabsKey(accountId, userId), {
    ticketIds: [...new Set(toIds(ticketIds))],
    activeTicketId: Number.isFinite(Number(activeTicketId))
      ? Number(activeTicketId)
      : null,
  });

// Which tab takes over when the active one is closed: the one to its left, so
// closing a run of tabs walks back the way the user opened them. Only at the
// head of the bar does it fall to the right, and an emptied bar returns null -
// the caller sends the user back to the Kanban.
export const neighbourTabId = (ticketIds, closedId) => {
  const index = ticketIds.indexOf(Number(closedId));
  if (index === -1) return null;

  const remaining = ticketIds.filter(id => id !== Number(closedId));
  if (!remaining.length) return null;

  return remaining[Math.max(index - 1, 0)];
};
