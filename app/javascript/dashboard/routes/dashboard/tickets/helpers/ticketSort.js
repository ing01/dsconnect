import { LocalStorage } from 'shared/helpers/localStorage';

// Field keys are the ones the ticket payload already carries, so sorting reads
// straight from what the board endpoint returned - no extra request.
export const TICKET_SORT_FIELDS = [
  'title',
  'display_id',
  'assignee_name',
  'company_name',
  'priority',
  'created_at',
  'status',
];

// Priority and status are Rails enums serialized as their string key, so they
// sort by the domain hierarchy rather than alphabetically.
const PRIORITY_ORDER = { low: 0, medium: 1, high: 2, urgent: 3 };
const STATUS_ORDER = { open: 0, resolved: 1, closed: 2 };

// A ticket with no value for the active field always sinks to the bottom,
// whichever direction is applied - flipping them to the top on `desc` would
// bury the tickets the user is actually looking at.
const sortKey = (ticket, field) => {
  switch (field) {
    case 'display_id':
      return {
        isEmpty: ticket.display_id == null,
        value: Number(ticket.display_id),
      };
    case 'created_at':
      return {
        isEmpty: ticket.created_at == null,
        value: Number(ticket.created_at),
      };
    case 'priority':
      return {
        isEmpty: !(ticket.priority in PRIORITY_ORDER),
        value: PRIORITY_ORDER[ticket.priority],
      };
    case 'status':
      return {
        isEmpty: !(ticket.status in STATUS_ORDER),
        value: STATUS_ORDER[ticket.status],
      };
    default: {
      const text = (ticket[field] ?? '').toString().trim();
      return { isEmpty: !text, value: text };
    }
  }
};

const compare = (a, b) =>
  typeof a === 'number'
    ? a - b
    : a.localeCompare(b, undefined, { sensitivity: 'base', numeric: true });

export const sortTickets = (tickets = [], sort = null) => {
  if (!sort?.field || !TICKET_SORT_FIELDS.includes(sort.field)) return tickets;

  const direction = sort.direction === 'desc' ? -1 : 1;

  // Copy first: the array handed in is the one Draggable mutates in place.
  return [...tickets].sort((first, second) => {
    const a = sortKey(first, sort.field);
    const b = sortKey(second, sort.field);

    if (a.isEmpty !== b.isEmpty) return a.isEmpty ? 1 : -1;
    if (a.isEmpty) return 0;

    return compare(a.value, b.value) * direction;
  });
};

// Sorting is a per-viewer preference like the collapsed columns, kept per Mesa
// so each board remembers how its owner likes to read it.
export const SORT_KEY_PREFIX = 'ticket-kanban-sort';

export const sortStorageKey = (accountId, teamId) =>
  `${SORT_KEY_PREFIX}::${accountId}::${teamId}`;

export const readSortPreference = (accountId, teamId) => {
  const stored = LocalStorage.get(sortStorageKey(accountId, teamId));
  if (!stored?.field || !TICKET_SORT_FIELDS.includes(stored.field)) return null;

  return {
    field: stored.field,
    direction: stored.direction === 'desc' ? 'desc' : 'asc',
  };
};

export const writeSortPreference = (accountId, teamId, sort) => {
  const key = sortStorageKey(accountId, teamId);
  if (sort?.field) LocalStorage.set(key, sort);
  else LocalStorage.remove(key);
};
