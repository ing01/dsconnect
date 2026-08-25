import { mount } from '@vue/test-utils';
import TicketActionsMenu from '../TicketActionsMenu.vue';

const mountMenu = (props = {}) =>
  mount(TicketActionsMenu, {
    props: { ticket: { status: 'open', conversations: [] }, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        DropdownMenu: {
          props: { menuItems: { type: Array, default: () => [] } },
          template:
            '<ul><li v-for="i in menuItems" :key="i.value" :data-value="i.value" :data-disabled="String(!!i.disabled)" @click="$emit(\'action\', i)">{{ i.label }}</li></ul>',
        },
      },
    },
  });

const open = async wrapper => {
  await wrapper.find('button').trigger('click');
  return wrapper;
};

const values = wrapper =>
  wrapper.findAll('li').map(li => li.attributes('data-value'));

describe('TicketActionsMenu', () => {
  it('stays closed until clicked', () => {
    expect(mountMenu().find('ul').exists()).toBe(false);
  });

  it('offers resolve and close for an open ticket, but not reopen', async () => {
    const items = values(await open(mountMenu()));

    expect(items).toContain('resolve');
    expect(items).toContain('close');
    expect(items).not.toContain('reopen');
  });

  it('offers reopen once the ticket is closed, and not close again', async () => {
    const wrapper = await open(
      mountMenu({ ticket: { status: 'closed', conversations: [] } })
    );
    const items = values(wrapper);

    expect(items).toContain('reopen');
    expect(items).not.toContain('close');
  });

  it('disables opening a conversation when none is linked', async () => {
    const wrapper = await open(mountMenu());
    const item = wrapper.find('[data-value="openConversation"]');

    expect(item.attributes('data-disabled')).toBe('true');
  });

  it('enables it once a conversation exists', async () => {
    const wrapper = await open(
      mountMenu({
        ticket: { status: 'open', conversations: [{ id: 1, display_id: 2 }] },
      })
    );

    expect(
      wrapper
        .find('[data-value="openConversation"]')
        .attributes('data-disabled')
    ).toBe('false');
  });

  it('disables the mutating actions without permission', async () => {
    const wrapper = await open(mountMenu({ canUpdate: false }));

    expect(
      wrapper.find('[data-value="edit"]').attributes('data-disabled')
    ).toBe('true');
    expect(
      wrapper.find('[data-value="resolve"]').attributes('data-disabled')
    ).toBe('true');
    // Copying the link never mutates anything.
    expect(
      wrapper.find('[data-value="copyLink"]').attributes('data-disabled')
    ).toBe('false');
  });

  it('emits the chosen action and closes', async () => {
    const wrapper = await open(mountMenu());
    await wrapper.find('[data-value="resolve"]').trigger('click');

    expect(wrapper.emitted('action')).toEqual([['resolve']]);
    expect(wrapper.find('ul').exists()).toBe(false);
  });
});
