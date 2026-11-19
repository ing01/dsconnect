import { actions, mutations, locateTicket } from '../../ticketColumns';
import types from '../../../mutation-types';
import TicketsAPI from '../../../../api/tickets';

vi.mock('../../../../api/tickets', () => ({ default: { move: vi.fn() } }));

const makeState = () => ({
  records: {
    7: {
      id: 7,
      ticket_columns: [
        {
          id: 10,
          tickets: [
            { id: 1, status: 'open', ticket_column_id: 10 },
            { id: 2, status: 'open', ticket_column_id: 10 },
          ],
        },
        {
          id: 11,
          tickets: [
            { id: 3, status: 'open', ticket_column_id: 11 },
            { id: 4, status: 'open', ticket_column_id: 11 },
          ],
        },
      ],
    },
  },
});

const idsIn = (state, columnId) =>
  state.records[7].ticket_columns
    .find(column => column.id === columnId)
    .tickets.map(t => t.id);

// Um `commit` de verdade: aplica a mutacao no estado, como a store faz.
const makeCommit = state => (type, payload) => mutations[type](state, payload);

describe('moving a ticket on the Kanban', () => {
  beforeEach(() => vi.clearAllMocks());

  describe('MOVE_TICKET_IN_KANBAN_BOARD', () => {
    it('puts the ticket at the dropped position in the other column', () => {
      const state = makeState();

      mutations[types.MOVE_TICKET_IN_KANBAN_BOARD](state, {
        ticketId: 1,
        columnId: 11,
        position: 1,
      });

      expect(idsIn(state, 10)).toEqual([2]);
      expect(idsIn(state, 11)).toEqual([3, 1, 4]);
      expect(
        state.records[7].ticket_columns[1].tickets[1].ticket_column_id
      ).toBe(11);
    });

    it('reorders inside the same column', () => {
      const state = makeState();

      mutations[types.MOVE_TICKET_IN_KANBAN_BOARD](state, {
        ticketId: 1,
        columnId: 10,
        position: 1,
      });

      expect(idsIn(state, 10)).toEqual([2, 1]);
    });

    it('clamps a position past the end and ignores an unknown column', () => {
      const state = makeState();

      mutations[types.MOVE_TICKET_IN_KANBAN_BOARD](state, {
        ticketId: 1,
        columnId: 11,
        position: 99,
      });
      expect(idsIn(state, 11)).toEqual([3, 4, 1]);

      mutations[types.MOVE_TICKET_IN_KANBAN_BOARD](state, {
        ticketId: 3,
        columnId: 999,
        position: 0,
      });
      expect(idsIn(state, 11)).toEqual([3, 4, 1]);
    });
  });

  describe('moveTicket action', () => {
    it('moves it in the state BEFORE the server answers, and keeps it there after', async () => {
      const state = makeState();
      let release;
      TicketsAPI.move.mockReturnValue(
        new Promise(resolve => {
          release = resolve;
        })
      );

      const pending = actions.moveTicket(
        { commit: makeCommit(state), state },
        { id: 1, ticketColumnId: 11, position: 0 }
      );

      expect(idsIn(state, 11)).toEqual([1, 3, 4]);

      release({
        data: { id: 1, status: 'open', ticket_column_id: 11, position: 0 },
      });
      await pending;

      expect(idsIn(state, 11)).toEqual([1, 3, 4]);
      expect(idsIn(state, 10)).toEqual([2]);
    });

    it('puts the ticket back where it was when the server refuses', async () => {
      const state = makeState();
      TicketsAPI.move.mockRejectedValue(new Error('blocked'));

      await expect(
        actions.moveTicket(
          { commit: makeCommit(state), state },
          { id: 2, ticketColumnId: 11, position: 0 }
        )
      ).rejects.toThrow('blocked');

      expect(idsIn(state, 10)).toEqual([1, 2]);
      expect(idsIn(state, 11)).toEqual([3, 4]);
    });
  });

  it('locates a ticket by column and index', () => {
    const state = makeState();

    expect(locateTicket(state, 4)).toEqual({ columnId: 11, index: 1 });
    expect(locateTicket(state, 404)).toBeNull();
  });
});
