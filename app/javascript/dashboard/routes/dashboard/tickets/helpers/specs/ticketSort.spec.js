import {
  sortTickets,
  sortStorageKey,
  readSortPreference,
  writeSortPreference,
} from '../ticketSort';

const ticket = (id, overrides = {}) => ({
  id,
  display_id: id,
  title: `Ticket ${id}`,
  assignee_name: null,
  company_name: null,
  priority: null,
  status: 'open',
  created_at: 1000 + id,
  ...overrides,
});

const idsOf = tickets => tickets.map(t => t.id);

describe('sortTickets', () => {
  it('leaves the list untouched without an active sort', () => {
    const tickets = [ticket(3), ticket(1), ticket(2)];

    expect(sortTickets(tickets, null)).toBe(tickets);
    expect(idsOf(sortTickets(tickets, { field: 'nope' }))).toEqual([3, 1, 2]);
  });

  it('does not mutate the array it was given', () => {
    const tickets = [ticket(3), ticket(1)];
    sortTickets(tickets, { field: 'display_id', direction: 'asc' });

    expect(idsOf(tickets)).toEqual([3, 1]);
  });

  describe('ticket number', () => {
    it('sorts numerically, not as text', () => {
      const tickets = [ticket(100), ticket(2), ticket(10), ticket(1)];

      expect(
        idsOf(sortTickets(tickets, { field: 'display_id', direction: 'asc' }))
      ).toEqual([1, 2, 10, 100]);
    });

    it('reverses on descending', () => {
      const tickets = [ticket(2), ticket(100), ticket(10)];

      expect(
        idsOf(sortTickets(tickets, { field: 'display_id', direction: 'desc' }))
      ).toEqual([100, 10, 2]);
    });
  });

  describe('title', () => {
    it('sorts A to Z ignoring case', () => {
      const tickets = [
        ticket(1, { title: 'banana' }),
        ticket(2, { title: 'Abacaxi' }),
        ticket(3, { title: 'cereja' }),
      ];

      expect(
        idsOf(sortTickets(tickets, { field: 'title', direction: 'asc' }))
      ).toEqual([2, 1, 3]);
    });
  });

  describe('assignee', () => {
    it('sorts by name and sinks the unassigned to the bottom', () => {
      const tickets = [
        ticket(1, { assignee_name: null }),
        ticket(2, { assignee_name: 'Carla' }),
        ticket(3, { assignee_name: 'Ana' }),
      ];

      expect(
        idsOf(
          sortTickets(tickets, { field: 'assignee_name', direction: 'asc' })
        )
      ).toEqual([3, 2, 1]);
    });

    it('keeps the unassigned at the bottom on descending too', () => {
      const tickets = [
        ticket(1, { assignee_name: null }),
        ticket(2, { assignee_name: 'Carla' }),
        ticket(3, { assignee_name: 'Ana' }),
      ];

      expect(
        idsOf(
          sortTickets(tickets, { field: 'assignee_name', direction: 'desc' })
        )
      ).toEqual([2, 3, 1]);
    });
  });

  describe('customer', () => {
    it('sorts alphabetically with the blanks last', () => {
      const tickets = [
        ticket(1, { company_name: 'Zeta' }),
        ticket(2, { company_name: '' }),
        ticket(3, { company_name: 'Alfa' }),
      ];

      expect(
        idsOf(sortTickets(tickets, { field: 'company_name', direction: 'asc' }))
      ).toEqual([3, 1, 2]);
    });
  });

  describe('priority', () => {
    it('follows the hierarchy, not the alphabet', () => {
      const tickets = [
        ticket(1, { priority: 'urgent' }),
        ticket(2, { priority: 'low' }),
        ticket(3, { priority: 'high' }),
        ticket(4, { priority: 'medium' }),
      ];

      expect(
        idsOf(sortTickets(tickets, { field: 'priority', direction: 'asc' }))
      ).toEqual([2, 4, 3, 1]);
      expect(
        idsOf(sortTickets(tickets, { field: 'priority', direction: 'desc' }))
      ).toEqual([1, 3, 4, 2]);
    });

    it('sinks tickets with no priority', () => {
      const tickets = [
        ticket(1, { priority: null }),
        ticket(2, { priority: 'low' }),
      ];

      expect(
        idsOf(sortTickets(tickets, { field: 'priority', direction: 'desc' }))
      ).toEqual([2, 1]);
    });
  });

  describe('ticket date', () => {
    it('sorts oldest first on ascending', () => {
      const tickets = [
        ticket(1, { created_at: 300 }),
        ticket(2, { created_at: 100 }),
        ticket(3, { created_at: 200 }),
      ];

      expect(
        idsOf(sortTickets(tickets, { field: 'created_at', direction: 'asc' }))
      ).toEqual([2, 3, 1]);
      expect(
        idsOf(sortTickets(tickets, { field: 'created_at', direction: 'desc' }))
      ).toEqual([1, 3, 2]);
    });
  });

  describe('status', () => {
    it('uses the lifecycle order rather than the alphabet', () => {
      const tickets = [
        ticket(1, { status: 'closed' }),
        ticket(2, { status: 'open' }),
        ticket(3, { status: 'resolved' }),
      ];

      expect(
        idsOf(sortTickets(tickets, { field: 'status', direction: 'asc' }))
      ).toEqual([2, 3, 1]);
    });
  });

  it('keeps the original order between ties', () => {
    const tickets = [
      ticket(5, { priority: 'low' }),
      ticket(3, { priority: 'low' }),
      ticket(9, { priority: 'low' }),
    ];

    expect(
      idsOf(sortTickets(tickets, { field: 'priority', direction: 'asc' }))
    ).toEqual([5, 3, 9]);
  });
});

describe('sort preference', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('scopes the key by account and Mesa', () => {
    expect(sortStorageKey(1, 7)).toBe('ticket-kanban-sort::1::7');
  });

  it('round-trips a preference', () => {
    writeSortPreference(1, 7, { field: 'created_at', direction: 'desc' });

    expect(readSortPreference(1, 7)).toEqual({
      field: 'created_at',
      direction: 'desc',
    });
  });

  it('keeps each Mesa independent', () => {
    writeSortPreference(1, 7, { field: 'title', direction: 'asc' });

    expect(readSortPreference(1, 8)).toBeNull();
  });

  it('clears the stored preference when sorting is dropped', () => {
    writeSortPreference(1, 7, { field: 'title', direction: 'asc' });
    writeSortPreference(1, 7, null);

    expect(readSortPreference(1, 7)).toBeNull();
  });

  it('ignores a stored field the app no longer knows', () => {
    window.localStorage.setItem(
      sortStorageKey(1, 7),
      JSON.stringify({ field: 'legacy_column', direction: 'asc' })
    );

    expect(readSortPreference(1, 7)).toBeNull();
  });

  it('falls back to ascending for a malformed direction', () => {
    writeSortPreference(1, 7, { field: 'title', direction: 'sideways' });

    expect(readSortPreference(1, 7).direction).toBe('asc');
  });
});
