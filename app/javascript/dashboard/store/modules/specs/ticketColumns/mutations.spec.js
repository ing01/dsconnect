import { mutations } from '../../ticketColumns';
import types from '../../../mutation-types';

const upsert = types.UPSERT_TICKET_IN_KANBAN_BOARD;

const ticket = (overrides = {}) => ({
  id: 1,
  status: 'open',
  ticket_column_id: 10,
  ...overrides,
});

const board = (columns = null) => ({
  records: {
    7: {
      id: 7,
      ticket_columns: columns || [
        { id: 10, tickets: [ticket()] },
        { id: 11, tickets: [] },
      ],
    },
  },
});

const idsIn = (state, columnId) =>
  state.records[7].ticket_columns
    .find(column => column.id === columnId)
    .tickets.map(t => t.id);

describe('ticketColumns mutations', () => {
  describe('UPSERT_TICKET_IN_KANBAN_BOARD', () => {
    it('updates a ticket already on the board', () => {
      const state = board();

      mutations[upsert](state, ticket({ title: 'novo' }));

      expect(idsIn(state, 10)).toEqual([1]);
      expect(state.records[7].ticket_columns[0].tickets[0].title).toBe('novo');
    });

    it('moves a ticket to its new column', () => {
      const state = board();

      mutations[upsert](state, ticket({ ticket_column_id: 11 }));

      expect(idsIn(state, 10)).toEqual([]);
      expect(idsIn(state, 11)).toEqual([1]);
    });

    it('adds a ticket the board had not seen', () => {
      const state = board();

      mutations[upsert](state, ticket({ id: 2, ticket_column_id: 11 }));

      expect(idsIn(state, 11)).toEqual([2]);
    });

    // The Kanban is the operational board: a ticket that just reached a terminal
    // state leaves it, here and on every other agent's board over realtime.
    describe('terminal tickets', () => {
      ['resolved', 'closed', 'cancelled'].forEach(status => {
        it(`removes a ${status} ticket from the board`, () => {
          const state = board();

          mutations[upsert](state, ticket({ status }));

          expect(idsIn(state, 10)).toEqual([]);
        });
      });

      it('never adds a terminal ticket the board had not seen', () => {
        const state = board();

        mutations[upsert](state, ticket({ id: 2, status: 'closed' }));

        expect(idsIn(state, 10)).toEqual([1]);
        expect(idsIn(state, 11)).toEqual([]);
      });

      it('removes it from whichever column it was sitting in', () => {
        const state = board([
          { id: 10, tickets: [] },
          { id: 11, tickets: [ticket({ ticket_column_id: 11 })] },
        ]);

        mutations[upsert](
          state,
          ticket({ status: 'closed', ticket_column_id: 11 })
        );

        expect(idsIn(state, 11)).toEqual([]);
      });

      it('leaves the other tickets alone', () => {
        const state = board([
          { id: 10, tickets: [ticket(), ticket({ id: 2 })] },
          { id: 11, tickets: [] },
        ]);

        mutations[upsert](state, ticket({ status: 'closed' }));

        expect(idsIn(state, 10)).toEqual([2]);
      });

      // Reopening puts it back, in the stage it belongs to.
      it('adds a reopened ticket back', () => {
        const state = board([
          { id: 10, tickets: [] },
          { id: 11, tickets: [] },
        ]);

        mutations[upsert](
          state,
          ticket({ status: 'open', ticket_column_id: 11 })
        );

        expect(idsIn(state, 11)).toEqual([1]);
      });
    });
  });
});
