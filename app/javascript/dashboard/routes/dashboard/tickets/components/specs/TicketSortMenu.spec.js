import { mount } from '@vue/test-utils';
import TicketSortMenu from '../TicketSortMenu.vue';

const mountMenu = (props = {}) =>
  mount(TicketSortMenu, {
    props,
    global: {
      mocks: { $t: key => key },
      directives: { tooltip: () => {} },
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Button: {
          props: ['icon'],
          template:
            '<button v-bind="$attrs" :data-icon="icon"><slot /></button>',
        },
        Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
      },
    },
  });

const open = async wrapper => {
  await wrapper.find('button[aria-haspopup="menu"]').trigger('click');
  return wrapper;
};

const rowButtons = (wrapper, fieldIndex) =>
  wrapper.findAll('li')[fieldIndex].findAll('button');

describe('TicketSortMenu', () => {
  it('is a single icon button while closed', () => {
    const wrapper = mountMenu();

    expect(wrapper.find('ul').exists()).toBe(false);
    expect(wrapper.find('button').attributes('aria-haspopup')).toBe('menu');
    expect(wrapper.find('button').attributes('aria-label')).toBe(
      'TICKET.SORT.BUTTON'
    );
  });

  it('lists every sortable field with both directions', async () => {
    const wrapper = await open(mountMenu());
    const rows = wrapper.findAll('li');

    expect(rows).toHaveLength(7);
    rows.forEach(row => expect(row.findAll('button')).toHaveLength(2));
  });

  it('emits the field and direction that was clicked', async () => {
    const wrapper = await open(mountMenu());
    // Second row is the ticket number.
    await rowButtons(wrapper, 1)[1].trigger('click');

    expect(wrapper.emitted('update')).toEqual([
      [{ field: 'display_id', direction: 'desc' }],
    ]);
  });

  it('closes after a direction is picked', async () => {
    const wrapper = await open(mountMenu());
    await rowButtons(wrapper, 0)[0].trigger('click');

    expect(wrapper.find('ul').exists()).toBe(false);
  });

  it('highlights the active field and direction only', async () => {
    const wrapper = await open(
      mountMenu({ sort: { field: 'display_id', direction: 'desc' } })
    );
    const pressed = wrapper
      .findAll('li button')
      .filter(b => b.attributes('aria-pressed') === 'true');

    expect(pressed).toHaveLength(1);
    expect(pressed[0].attributes('aria-label')).toBe('TICKET.SORT.DESC_BY');
  });

  it('drops the sort when the active direction is clicked again', async () => {
    const wrapper = await open(
      mountMenu({ sort: { field: 'title', direction: 'asc' } })
    );
    await rowButtons(wrapper, 0)[0].trigger('click');

    expect(wrapper.emitted('update')).toEqual([[null]]);
  });

  it('replaces the sort when another direction is picked', async () => {
    const wrapper = await open(
      mountMenu({ sort: { field: 'title', direction: 'asc' } })
    );
    await rowButtons(wrapper, 0)[1].trigger('click');

    expect(wrapper.emitted('update')).toEqual([
      [{ field: 'title', direction: 'desc' }],
    ]);
  });

  describe('clear', () => {
    const clearButton = wrapper =>
      wrapper.findAll('button').find(b => b.text() === 'TICKET.SORT.CLEAR');

    it('is disabled while no sort is active', async () => {
      const wrapper = await open(mountMenu());

      expect(clearButton(wrapper).attributes('disabled')).toBeDefined();
    });

    it('is enabled and resets the sort once one is active', async () => {
      const wrapper = await open(
        mountMenu({ sort: { field: 'status', direction: 'asc' } })
      );
      expect(clearButton(wrapper).attributes('disabled')).toBeUndefined();

      await clearButton(wrapper).trigger('click');
      expect(wrapper.emitted('update')).toEqual([[null]]);
    });
  });
});
