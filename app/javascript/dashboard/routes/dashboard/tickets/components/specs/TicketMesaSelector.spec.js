import { mount } from '@vue/test-utils';
import TicketMesaSelector from '../TicketMesaSelector.vue';

const teams = [
  { id: 1, name: 'comercial' },
  { id: 2, name: 'suporte' },
  { id: 3, name: 'banco de ideias - produto' },
];

const mountSelector = (props = {}) =>
  mount(TicketMesaSelector, {
    props: { teams, selectedTeamId: 2, ...props },
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${Object.values(params).join(',')}` : key,
      },
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        // `onClick` arrives through $attrs; re-emitting would fire the
        // handler twice and cancel the toggle.
        Button: {
          props: ['icon'],
          template: '<button v-bind="$attrs"><slot /></button>',
        },
        Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
        DropdownMenu: {
          // Boolean type matters: a valueless `show-search` attribute only
          // casts to `true` when the prop declares its type.
          props: {
            menuItems: Array,
            showSearch: Boolean,
            searchPlaceholder: String,
          },
          template:
            '<ul :data-search="String(showSearch)" :data-placeholder="searchPlaceholder"><li v-for="i in menuItems" :key="i.value" :data-icon="i.icon" :data-selected="i.isSelected" @click="$emit(\'action\', i)">{{ i.label }}</li></ul>',
        },
      },
    },
  });

const open = async wrapper => {
  await wrapper.find('button').trigger('click');
  return wrapper;
};

describe('TicketMesaSelector', () => {
  describe('closed state', () => {
    it('shows the selected Mesa, capitalized', () => {
      // `t()` returns the bare key here, so the rendered label is asserted
      // through the title attribute that carries the resolved Mesa name.
      expect(mountSelector().find('button span').attributes('title')).toBe(
        'Suporte'
      );
    });

    it('falls back to a prompt when no Mesa is selected', () => {
      const wrapper = mountSelector({ selectedTeamId: null });

      expect(wrapper.find('button span').attributes('title')).toBe(
        'TICKET.MESA_SELECTOR.NONE'
      );
    });

    it('points the chevron down while closed and up while open', async () => {
      const wrapper = mountSelector();
      expect(wrapper.find('[data-icon="i-lucide-chevron-down"]').exists()).toBe(
        true
      );

      await open(wrapper);
      expect(wrapper.find('[data-icon="i-lucide-chevron-up"]').exists()).toBe(
        true
      );
    });

    it('keeps the dropdown closed until clicked', () => {
      expect(mountSelector().find('ul').exists()).toBe(false);
    });

    it('announces itself as a menu trigger', () => {
      const button = mountSelector().find('button');

      expect(button.attributes('aria-haspopup')).toBe('menu');
      expect(button.attributes('aria-expanded')).toBe('false');
    });
  });

  describe('dropdown', () => {
    it('offers a search field over the Mesas', async () => {
      const menu = (await open(mountSelector())).find('ul');

      expect(menu.attributes('data-search')).toBe('true');
      expect(menu.attributes('data-placeholder')).toBe(
        'TICKET.MESA_SELECTOR.SEARCH'
      );
    });

    it('lists every Mesa with a star, capitalized', async () => {
      const items = (await open(mountSelector())).findAll('li');

      expect(items.map(i => i.text())).toEqual([
        'Comercial',
        'Suporte',
        'Banco De Ideias - Produto',
      ]);
      expect(
        items.every(i => i.attributes('data-icon') === 'i-lucide-star')
      ).toBe(true);
    });

    it('marks only the current Mesa as selected', async () => {
      const items = (await open(mountSelector())).findAll('li');

      expect(items.map(i => i.attributes('data-selected'))).toEqual([
        'false',
        'true',
        'false',
      ]);
    });
  });

  describe('picking a Mesa', () => {
    it('emits the chosen team id and closes', async () => {
      const wrapper = await open(mountSelector());
      await wrapper.findAll('li')[0].trigger('click');

      expect(wrapper.emitted('select')).toEqual([[1]]);
      expect(wrapper.find('ul').exists()).toBe(false);
    });

    it('just closes when the current Mesa is picked again', async () => {
      const wrapper = await open(mountSelector());
      await wrapper.findAll('li')[1].trigger('click');

      expect(wrapper.emitted('select')).toBeUndefined();
      expect(wrapper.find('ul').exists()).toBe(false);
    });
  });
});
