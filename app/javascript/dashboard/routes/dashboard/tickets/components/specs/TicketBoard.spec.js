import { shallowMount } from '@vue/test-utils';
import TicketBoard from '../TicketBoard.vue';
import TicketBoardColumn from '../TicketBoardColumn.vue';
import { writeCollapsedColumnIds } from '../../helpers/collapsedColumns';

const board = {
  id: 7,
  name: 'suporte',
  ticket_columns: [
    { id: 1, name: 'Em andamento', position: 0, team_id: 7, tickets: [] },
    {
      id: 2,
      name: 'A fazer',
      position: 1,
      team_id: 7,
      tickets: [{ id: 101, title: 'Erro NF' }],
    },
    { id: 3, name: 'Concluído', position: 2, team_id: 7, tickets: [] },
  ],
};

const mountBoard = (props = {}) =>
  shallowMount(TicketBoard, {
    props: { board, accountId: 1, teamId: 7, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: { TicketBoardColumn: true },
    },
  });

describe('TicketBoard', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('renders one column per Estagio, in the order the backend sent', () => {
    const columns = mountBoard().findAllComponents(TicketBoardColumn);

    expect(columns).toHaveLength(3);
    expect(columns.map(c => c.props('column').name)).toEqual([
      'Em andamento',
      'A fazer',
      'Concluído',
    ]);
  });

  it('does not offer stage creation on the board', () => {
    expect(mountBoard().text()).not.toContain('ADD_COLUMN');
    expect(mountBoard().findAll('button')).toHaveLength(0);
  });

  // jsdom does not lay out CSS, so these assert the class contract that keeps
  // the columns from widening the page and pushing the header out of reach.
  describe('horizontal scroll containment', () => {
    it('scrolls inside a viewport capped at the width the page gives it', () => {
      const viewport = mountBoard().element;

      expect(viewport.className).toContain('overflow-x-auto');
      expect(viewport.className).toContain('max-w-full');
      expect(viewport.className).toContain('min-w-0');
      expect(viewport.className).toContain('w-full');
    });

    it('lets the column strip grow past the viewport instead of being squeezed', () => {
      const content = mountBoard().element.firstElementChild;

      expect(content.className).toContain('w-max');
      expect(content.className).not.toContain('overflow');
    });

    it('keeps the same containment with many Estagios', () => {
      const wide = {
        ...board,
        ticket_columns: Array.from({ length: 15 }, (_, i) => ({
          id: i + 1,
          name: `Estagio ${i + 1}`,
          position: i,
          team_id: 7,
          tickets: [],
        })),
      };
      const wrapper = mountBoard({ board: wide });

      expect(wrapper.findAllComponents(TicketBoardColumn)).toHaveLength(15);
      expect(wrapper.element.className).toContain('overflow-x-auto');
      expect(wrapper.element.className).toContain('max-w-full');
    });
  });

  it('applies the collapsed state persisted for this Mesa', () => {
    writeCollapsedColumnIds(1, 7, [3]);

    const columns = mountBoard().findAllComponents(TicketBoardColumn);

    expect(columns.map(c => c.props('isCollapsed'))).toEqual([
      false,
      false,
      true,
    ]);
  });

  it('ignores collapsed state stored for a different Mesa', () => {
    writeCollapsedColumnIds(1, 8, [3]);

    const columns = mountBoard().findAllComponents(TicketBoardColumn);

    expect(columns.every(c => c.props('isCollapsed') === false)).toBe(true);
  });

  it('persists a toggle so it survives a remount', async () => {
    const wrapper = mountBoard();
    wrapper.vm.toggleColumn(2);

    const remounted = mountBoard().findAllComponents(TicketBoardColumn);
    expect(remounted[1].props('isCollapsed')).toBe(true);
  });

  describe('sorting', () => {
    const boardWithTickets = {
      ...board,
      ticket_columns: [
        {
          id: 1,
          name: 'Em andamento',
          position: 0,
          team_id: 7,
          tickets: [
            { id: 10, display_id: 10, title: 'C' },
            { id: 2, display_id: 2, title: 'A' },
            { id: 100, display_id: 100, title: 'B' },
          ],
        },
      ],
    };

    it('leaves the backend order alone with no sort active', () => {
      const wrapper = mountBoard({ board: boardWithTickets });

      expect(wrapper.vm.localColumns[1].map(t => t.id)).toEqual([10, 2, 100]);
    });

    it('orders each column by the active sort', () => {
      const wrapper = mountBoard({
        board: boardWithTickets,
        sort: { field: 'display_id', direction: 'asc' },
      });

      expect(wrapper.vm.localColumns[1].map(t => t.id)).toEqual([2, 10, 100]);
    });

    it('reorders when the sort changes, without a refetch', async () => {
      const wrapper = mountBoard({
        board: boardWithTickets,
        sort: { field: 'display_id', direction: 'asc' },
      });
      await wrapper.setProps({
        sort: { field: 'display_id', direction: 'desc' },
      });

      expect(wrapper.vm.localColumns[1].map(t => t.id)).toEqual([100, 10, 2]);
    });

    // Realtime upserts and the refetch after a drag both replace `board`, so
    // this covers the ordering both of them land on.
    it('reorders when the board data itself changes', async () => {
      const wrapper = mountBoard({
        board: boardWithTickets,
        sort: { field: 'display_id', direction: 'asc' },
      });
      await wrapper.setProps({
        board: {
          ...boardWithTickets,
          ticket_columns: [
            {
              ...boardWithTickets.ticket_columns[0],
              tickets: [
                ...boardWithTickets.ticket_columns[0].tickets,
                { id: 1, display_id: 1, title: 'Novo' },
              ],
            },
          ],
        },
      });

      expect(wrapper.vm.localColumns[1].map(t => t.id)).toEqual([
        1, 2, 10, 100,
      ]);
    });

    it('never moves a ticket out of its own column', () => {
      const wrapper = mountBoard({
        board,
        sort: { field: 'display_id', direction: 'desc' },
      });

      expect(wrapper.vm.localColumns[1]).toHaveLength(0);
      expect(wrapper.vm.localColumns[2].map(t => t.id)).toEqual([101]);
      expect(wrapper.vm.localColumns[3]).toHaveLength(0);
    });
  });

  it('keeps every ticket when a column is collapsed and expanded again', () => {
    const wrapper = mountBoard();
    const ticketsBefore = wrapper.vm.localColumns[2].length;

    wrapper.vm.toggleColumn(2);
    wrapper.vm.toggleColumn(2);

    expect(wrapper.vm.localColumns[2]).toHaveLength(ticketsBefore);
  });
});
