import { mount } from '@vue/test-utils';
import TicketCard from '../TicketCard.vue';

const ticket = (overrides = {}) => ({
  id: 11,
  display_id: 26,
  title: 'Erro na emissão da nota',
  status: 'open',
  priority: 'medium',
  assignee_id: null,
  conversation_ids: [],
  ...overrides,
});

const mountCard = (props = {}) =>
  mount(TicketCard, {
    props: { ticket: ticket(), agents: [], ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        Avatar: true,
        WootLabel: true,
        OnClickOutside: { template: '<div><slot /></div>' },
        // No `emits` and no `$emit`: the toggle is bound with `@click.stop`,
        // which needs a real event object, so the native click has to fall
        // through to the root button.
        NextButton: { template: '<button />' },
        // Mirrors the real DropdownMenu contract: each item carries its own
        // `action`, which is what paints the destructive entry red.
        DropdownMenu: {
          props: { menuItems: { type: Array, default: () => [] } },
          template: `<ul>
            <li
              v-for="i in menuItems"
              :key="i.value"
              :data-value="i.value"
              :data-action="i.action"
              @click="$emit('action', i)"
            >{{ i.label }}</li>
          </ul>`,
        },
      },
    },
  });

const openMenu = async wrapper => {
  await wrapper.find('button').trigger('click');
  return wrapper;
};

const values = wrapper =>
  wrapper.findAll('li').map(li => li.attributes('data-value'));

describe('TicketCard menu', () => {
  it('stays closed until the menu button is clicked', () => {
    expect(mountCard().find('ul').exists()).toBe(false);
  });

  it('offers exactly the six operational actions, in order', async () => {
    const wrapper = await openMenu(mountCard());

    expect(values(wrapper)).toEqual([
      'assignToMe',
      'sendCommunication',
      'merge',
      'createChild',
      'transfer',
      'close',
    ]);
  });

  // Editing happens inside the ticket, closing is what ends an attendance, and
  // clicking the card already opens it.
  it('no longer offers open, edit or resolve', async () => {
    const items = values(await openMenu(mountCard()));

    ['open', 'edit', 'resolve'].forEach(gone =>
      expect(items).not.toContain(gone)
    );
  });

  // `action: 'delete'` is what DropdownMenu paints in ruby.
  it('marks closing as the destructive entry, at the end', async () => {
    const wrapper = await openMenu(mountCard());
    const entries = wrapper.findAll('li');

    expect(entries.at(-1).attributes('data-value')).toBe('close');
    expect(entries.at(-1).attributes('data-action')).toBe('delete');
  });

  it('names the action and the ticket in one event', async () => {
    const wrapper = await openMenu(mountCard());

    await wrapper.find('[data-value="transfer"]').trigger('click');

    expect(wrapper.emitted('menuAction')).toEqual([
      [{ action: 'transfer', ticket: ticket() }],
    ]);
  });

  it('closes the menu after choosing', async () => {
    const wrapper = await openMenu(mountCard());

    await wrapper.find('[data-value="merge"]').trigger('click');

    expect(wrapper.find('ul').exists()).toBe(false);
  });

  // A terminal ticket is off the operational board; reopening is all that is
  // left to do with it.
  describe('a ticket that is no longer open', () => {
    ['resolved', 'closed', 'cancelled'].forEach(status => {
      it(`offers only reopen when ${status}`, async () => {
        const wrapper = await openMenu(mountCard({ ticket: ticket({ status }) }));

        expect(values(wrapper)).toEqual(['reopen']);
      });
    });
  });
});
