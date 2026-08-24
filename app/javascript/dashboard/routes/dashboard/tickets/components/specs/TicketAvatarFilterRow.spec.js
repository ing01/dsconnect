import { mount } from '@vue/test-utils';
import TicketAvatarFilterRow from '../TicketAvatarFilterRow.vue';

const agent = id => ({
  id,
  name: `Agente ${id}`,
  thumbnail: id % 2 ? `https://example.test/${id}.png` : '',
});

const mountRow = (props = {}) =>
  mount(TicketAvatarFilterRow, {
    props: { agents: [agent(1), agent(2), agent(3)], ...props },
    global: {
      mocks: { $t: key => key },
      directives: { tooltip: () => {} },
      stubs: {
        Avatar: {
          props: ['name', 'src'],
          template: '<i :data-name="name" :data-src="src" />',
        },
        DropdownMenu: {
          props: ['menuItems'],
          template:
            '<ul><li v-for="i in menuItems" :key="i.value" :data-selected="i.isSelected" @click="$emit(\'action\', i)">{{ i.label }}</li></ul>',
        },
      },
    },
  });

// [0] is "Todos"; agents start at index 1.
const avatarButton = (wrapper, index) => wrapper.findAll('button')[index];

describe('TicketAvatarFilterRow', () => {
  it('renders one avatar per Mesa member', () => {
    expect(mountRow().findAll('[data-name]')).toHaveLength(3);
  });

  it('passes the image through when the member has one', () => {
    const avatars = mountRow().findAll('[data-name]');

    expect(avatars[0].attributes('data-src')).toBe(
      'https://example.test/1.png'
    );
    expect(avatars[1].attributes('data-src')).toBe('');
  });

  it('labels each avatar with the member name for tooltip and a11y', () => {
    expect(avatarButton(mountRow(), 1).attributes('aria-label')).toBe(
      'Agente 1'
    );
  });

  it('offers an "all" option that is active while nothing is selected', () => {
    const all = avatarButton(mountRow(), 0);

    expect(all.text()).toBe('TICKET.FILTERS.ALL_AGENTS');
    expect(all.attributes('aria-pressed')).toBe('true');
  });

  describe('selecting several agents', () => {
    it('adds the first agent to an empty filter', async () => {
      const wrapper = mountRow();
      await avatarButton(wrapper, 1).trigger('click');

      expect(wrapper.emitted('select')).toEqual([[[1]]]);
    });

    it('adds a second agent without dropping the first', async () => {
      const wrapper = mountRow({ selectedAgentIds: [1] });
      await avatarButton(wrapper, 2).trigger('click');

      expect(wrapper.emitted('select')).toEqual([[[1, 2]]]);
    });

    it('removes only the agent clicked again', async () => {
      const wrapper = mountRow({ selectedAgentIds: [1, 2, 3] });
      await avatarButton(wrapper, 2).trigger('click');

      expect(wrapper.emitted('select')).toEqual([[[1, 3]]]);
    });

    it('highlights every selected agent', () => {
      // Selected agents are hoisted to the front, so assert by name.
      const wrapper = mountRow({ selectedAgentIds: [1, 3] });
      const ringed = wrapper
        .findAll('button[aria-label]')
        .filter(button => button.classes().includes('ring-2'))
        .map(button => button.attributes('aria-label'));

      expect(ringed).toEqual(['Agente 1', 'Agente 3']);
    });

    it('drops the "all" highlight while a filter is active', () => {
      const wrapper = mountRow({ selectedAgentIds: [1] });

      expect(avatarButton(wrapper, 0).attributes('aria-pressed')).toBe('false');
    });
  });

  describe('clear filter', () => {
    it('is hidden while nothing is selected', () => {
      expect(mountRow().text()).not.toContain('TICKET.FILTERS.CLEAR');
    });

    it('shows up as soon as an agent is selected', () => {
      expect(mountRow({ selectedAgentIds: [1] }).text()).toContain(
        'TICKET.FILTERS.CLEAR'
      );
    });

    it('empties the whole selection in one click', async () => {
      const wrapper = mountRow({ selectedAgentIds: [1, 2] });
      const clear = wrapper
        .findAll('button')
        .find(button => button.text() === 'TICKET.FILTERS.CLEAR');
      await clear.trigger('click');

      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });

    it('is also what the "all" chip does', async () => {
      const wrapper = mountRow({ selectedAgentIds: [1, 2] });
      await avatarButton(wrapper, 0).trigger('click');

      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });
  });

  describe('with more members than fit', () => {
    const many = Array.from({ length: 20 }, (_, i) => agent(i + 1));

    it('caps the avatars and groups the rest behind +N', () => {
      const wrapper = mountRow({ agents: many });

      expect(wrapper.findAll('[data-name]')).toHaveLength(6);
      expect(wrapper.text()).toContain('+14');
    });

    it('adds an overflow member to the selection without replacing it', async () => {
      const wrapper = mountRow({ agents: many, selectedAgentIds: [1] });
      await wrapper.find('[aria-haspopup="menu"]').trigger('click');
      await wrapper.findAll('li')[0].trigger('click');

      expect(wrapper.emitted('select')).toEqual([[[1, 7]]]);
    });

    it('marks the already selected members inside the menu', async () => {
      const wrapper = mountRow({ agents: many, selectedAgentIds: [20] });
      await wrapper.find('[aria-haspopup="menu"]').trigger('click');
      const selectedItems = wrapper
        .findAll('li')
        .filter(li => li.attributes('data-selected') === 'true');

      expect(selectedItems).toHaveLength(0);
    });

    it('keeps every selected agent on the row, even from the overflow', () => {
      const wrapper = mountRow({
        agents: many,
        selectedAgentIds: [15, 18],
      });
      const names = wrapper
        .findAll('[data-name]')
        .map(a => a.attributes('data-name'));

      expect(names.slice(0, 2)).toEqual(['Agente 15', 'Agente 18']);
      expect(names).toHaveLength(6);
    });

    it('still shows all selected agents when there are more than the cap', () => {
      const wrapper = mountRow({
        agents: many,
        selectedAgentIds: [1, 2, 3, 4, 5, 6, 7, 8],
      });

      expect(wrapper.findAll('[data-name]')).toHaveLength(8);
    });
  });

  it('explains the empty state instead of showing a bare row', () => {
    const wrapper = mountRow({ agents: [] });

    expect(wrapper.text()).toContain('TICKET.FILTERS.NO_MESA_MEMBERS');
    expect(wrapper.findAll('[data-name]')).toHaveLength(0);
  });
});
