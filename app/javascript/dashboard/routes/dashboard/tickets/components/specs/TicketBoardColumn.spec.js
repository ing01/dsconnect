import { shallowMount } from '@vue/test-utils';
import TicketBoardColumn from '../TicketBoardColumn.vue';

const column = { id: 3, name: 'A fazer', position: 1, team_id: 7 };

const ticket = (id, overrides = {}) => ({
  id,
  title: `Ticket ${id}`,
  display_id: id,
  assignee_id: null,
  team_id: 7,
  ticket_column_id: 3,
  ...overrides,
});

const mountColumn = (props = {}) =>
  shallowMount(TicketBoardColumn, {
    props: {
      column,
      tickets: [ticket(101), ticket(102), ticket(103)],
      ...props,
    },
    global: {
      // `$t` echoes the key plus any interpolation so aria-labels stay assertable.
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${Object.values(params).join(',')}` : key,
      },
      directives: { tooltip: () => {} },
      stubs: {
        // Stands in for vuedraggable: renders the item slot once per ticket
        // with the same slot prop the real component passes.
        Draggable: {
          props: {
            list: { type: Array, default: () => [] },
            disabled: { type: Boolean, default: false },
          },
          template:
            '<div :data-disabled="String(disabled)"><slot v-for="element in list" name="item" :element="element" /></div>',
        },
        Icon: true,
        TicketCard: true,
      },
    },
  });

describe('TicketBoardColumn', () => {
  // A Area do Cliente monta ESTE componente, e nao uma copia dele - por isso o
  // modo leitura mora aqui. O padrao e `false`: o Kanban dos agentes nao muda.
  describe('read-only', () => {
    const draggable = wrapper => wrapper.find('[data-disabled]');
    const addButton = wrapper =>
      wrapper
        .findAll('button')
        .filter(b => b.attributes('aria-label')?.includes('ADD_TICKET'));

    it('keeps drag and the add button for agents', () => {
      const wrapper = mountColumn();

      expect(draggable(wrapper).attributes('data-disabled')).toBe('false');
      expect(addButton(wrapper)).toHaveLength(1);
    });

    it('drops drag and the add button when read only', () => {
      const wrapper = mountColumn({ readOnly: true });

      expect(draggable(wrapper).attributes('data-disabled')).toBe('true');
      expect(addButton(wrapper)).toHaveLength(0);
    });

    it('passes the mode down to the card', () => {
      const wrapper = mountColumn({ readOnly: true });

      expect(
        wrapper.findComponent({ name: 'TicketCard' }).props('readOnly')
      ).toBe(true);
    });
  });

  describe('counter', () => {
    it('shows the number of tickets in the stage', () => {
      expect(mountColumn().vm.visibleCount).toBe(3);
    });

    it('reflects the active agent filter', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { assignee_id: 9 }),
          ticket(102, { assignee_id: 4 }),
          ticket(103, { assignee_id: 9 }),
        ],
        filters: { assigneeIds: [9] },
      });

      expect(wrapper.vm.visibleCount).toBe(2);
    });

    it('counts every selected agent, without double counting', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { assignee_id: 9 }),
          ticket(102, { assignee_id: 4 }),
          ticket(103, { assignee_id: 7 }),
        ],
        filters: { assigneeIds: [9, 4] },
      });

      expect(wrapper.vm.visibleCount).toBe(2);
    });

    it('falls back to the full count when the filter is cleared', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { assignee_id: 9 }),
          ticket(102, { assignee_id: null }),
        ],
        filters: { assigneeIds: [] },
      });

      expect(wrapper.vm.visibleCount).toBe(2);
    });

    it('narrows the count by ticket number', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { display_id: 12 }),
          ticket(102, { display_id: 34 }),
        ],
        filters: { query: '12' },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('accepts the ticket number written with a leading #', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { display_id: 12 }),
          ticket(102, { display_id: 34 }),
        ],
        filters: { query: '#12' },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('narrows the count by title, case-insensitively', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { title: 'Erro na nota fiscal' }),
          ticket(102, { title: 'Instalacao terminal' }),
        ],
        filters: { query: 'ERRO NA NOTA' },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('narrows the count by assignee name', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { assignee_name: 'João Vitor' }),
          ticket(102, { assignee_name: 'Carla Reis' }),
        ],
        filters: { query: 'joão' },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('narrows the count by company name', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { company_name: 'ELETROSUL - FILIAL' }),
          ticket(102, { company_name: 'EMPRESA ABC' }),
        ],
        filters: { query: 'eletrosul' },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('combines the quick search with the agent filter', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { assignee_id: 9, title: 'Erro na nota' }),
          ticket(102, { assignee_id: 4, title: 'Erro na nota' }),
          ticket(103, { assignee_id: 9, title: 'Outro assunto' }),
        ],
        filters: { assigneeIds: [9], query: 'erro' },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('restores the full count when the search is cleared', () => {
      const wrapper = mountColumn({
        tickets: [ticket(101, { title: 'Erro' }), ticket(102)],
        filters: { query: '' },
      });

      expect(wrapper.vm.visibleCount).toBe(2);
    });

    it('keeps unassigned tickets out of an agent filter', () => {
      const wrapper = mountColumn({
        tickets: [
          ticket(101, { assignee_id: 9 }),
          ticket(102, { assignee_id: null }),
        ],
        filters: { assigneeIds: [9] },
      });

      expect(wrapper.vm.visibleCount).toBe(1);
    });

    it('follows the ticket list when a card is dropped in or out', async () => {
      const wrapper = mountColumn({ tickets: [ticket(101), ticket(102)] });
      expect(wrapper.vm.visibleCount).toBe(2);

      await wrapper.setProps({
        tickets: [ticket(101), ticket(102), ticket(103)],
      });
      expect(wrapper.vm.visibleCount).toBe(3);

      await wrapper.setProps({ tickets: [ticket(101)] });
      expect(wrapper.vm.visibleCount).toBe(1);
    });
  });

  describe('collapsing', () => {
    it('hides the cards and the add-ticket button when collapsed', () => {
      const wrapper = mountColumn({ isCollapsed: true });

      expect(wrapper.findComponent({ name: 'TicketCard' }).exists()).toBe(
        false
      );
      expect(
        wrapper
          .find('[aria-label^="TICKET.BOARD.ADD_TICKET_TO_COLUMN"]')
          .exists()
      ).toBe(false);
    });

    it('still shows the stage name and its counter when collapsed', () => {
      const wrapper = mountColumn({ isCollapsed: true });

      expect(wrapper.text()).toContain('A fazer');
      expect(wrapper.text()).toContain('3');
    });

    it('turns the collapsed name on its side, reading top to bottom', () => {
      const name = mountColumn({ isCollapsed: true }).find('span[title]');

      expect(name.classes()).toContain('[writing-mode:vertical-rl]');
      // Upright would stack the letters one per line instead of rotating the word.
      expect(name.classes()).not.toContain('[text-orientation:upright]');
    });

    it('gives the collapsed column a definite height to flex against', () => {
      // The rotated name takes `flex-1`, which is `flex-basis: 0%` - without
      // `h-full` on the column there is no leftover height and the name vanishes.
      const wrapper = mountColumn({ isCollapsed: true });

      expect(wrapper.classes()).toContain('h-full');
      expect(wrapper.find('span[title]').classes()).toContain('flex-1');
    });

    it('puts the counter after the name, at the foot of the column', () => {
      const wrapper = mountColumn({ isCollapsed: true });
      const spans = wrapper.findAll('span');

      expect(spans[spans.length - 1].text()).toBe('3');
    });

    it('takes noticeably less width when collapsed', () => {
      expect(mountColumn().classes()).toContain('w-72');
      expect(mountColumn({ isCollapsed: true }).classes()).toContain('w-14');
    });

    it('restores the cards and the add-ticket button when expanded', async () => {
      const wrapper = mountColumn({ isCollapsed: true });
      await wrapper.setProps({ isCollapsed: false });

      expect(
        wrapper
          .find('[aria-label^="TICKET.BOARD.ADD_TICKET_TO_COLUMN"]')
          .exists()
      ).toBe(true);
      expect(wrapper.vm.visibleCount).toBe(3);
    });

    it('emits toggle-collapse with the stage id', async () => {
      const wrapper = mountColumn();
      await wrapper.find('button').trigger('click');

      expect(wrapper.emitted('toggleCollapse')).toEqual([[column.id]]);
    });

    it('expands again from the collapsed state', async () => {
      const wrapper = mountColumn({ isCollapsed: true });
      await wrapper.find('button').trigger('click');

      expect(wrapper.emitted('toggleCollapse')).toEqual([[column.id]]);
    });
  });

  describe('collapse control', () => {
    const toggleButton = wrapper => wrapper.findAll('button')[0];

    it('is a real button, not a bare icon', () => {
      expect(toggleButton(mountColumn()).element.tagName).toBe('BUTTON');
      expect(toggleButton(mountColumn()).attributes('type')).toBe('button');
    });

    it('offers a comfortable hit area that does not shrink', () => {
      const classes = toggleButton(mountColumn()).classes();

      expect(classes).toContain('size-8');
      expect(classes).toContain('flex-shrink-0');
    });

    it('keeps that hit area in the collapsed state too', () => {
      const classes = toggleButton(
        mountColumn({ isCollapsed: true })
      ).classes();

      expect(classes).toContain('size-8');
      expect(classes).toContain('flex-shrink-0');
    });

    it('reacts on hover and on keyboard focus', () => {
      const classes = toggleButton(mountColumn()).classes().join(' ');

      expect(classes).toContain('hover:bg-n-slate-4');
      expect(classes).toContain('focus-visible:ring-2');
    });

    it('names the column it acts on for screen readers', () => {
      expect(toggleButton(mountColumn()).attributes('aria-label')).toBe(
        'TICKET.BOARD.COLLAPSE_COLUMN:A fazer'
      );
      expect(
        toggleButton(mountColumn({ isCollapsed: true })).attributes(
          'aria-label'
        )
      ).toBe('TICKET.BOARD.EXPAND_COLUMN:A fazer');
    });

    it('shows a panel icon pointing at what the click will do', () => {
      expect(mountColumn().findComponent({ name: 'Icon' }).props('icon')).toBe(
        'i-lucide-panel-left-close'
      );
      expect(
        mountColumn({ isCollapsed: true })
          .findComponent({ name: 'Icon' })
          .props('icon')
      ).toBe('i-lucide-panel-left-open');
    });

    it('sits next to an add-ticket button of the same size', () => {
      const wrapper = mountColumn();
      const add = wrapper.find(
        '[aria-label^="TICKET.BOARD.ADD_TICKET_TO_COLUMN"]'
      );

      expect(add.element.tagName).toBe('BUTTON');
      expect(add.classes()).toContain('size-8');
      expect(add.classes()).toContain('flex-shrink-0');
    });

    it('emits add-ticket with the column from the header button', async () => {
      const wrapper = mountColumn();
      await wrapper
        .find('[aria-label^="TICKET.BOARD.ADD_TICKET_TO_COLUMN"]')
        .trigger('click');

      expect(wrapper.emitted('addTicket')).toEqual([[column]]);
    });
  });

  describe('stage administration', () => {
    it('offers no edit or delete action on the board', () => {
      const wrapper = mountColumn();

      expect(wrapper.emitted('edit-column')).toBeUndefined();
      // Only the collapse toggle and the add-ticket button remain.
      expect(wrapper.findAll('button')).toHaveLength(2);
    });
  });
});
