import { mount } from '@vue/test-utils';
import TicketActionsMenu from '../TicketActionsMenu.vue';

const ticket = (overrides = {}) => ({
  id: 1,
  status: 'open',
  assignee_id: null,
  conversations: [],
  ...overrides,
});

const mountMenu = (props = {}) =>
  mount(TicketActionsMenu, {
    props: { ticket: ticket(), ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        // Mirrors the real DropdownMenu contract: sections render in order,
        // each item carrying its own `action` (which is what paints the
        // destructive entries red).
        DropdownMenu: {
          props: { menuSections: { type: Array, default: () => [] } },
          template: `<ul>
            <template v-for="(s, si) in menuSections" :key="si">
              <li
                v-for="i in s.items"
                :key="i.value"
                :data-value="i.value"
                :data-section="si"
                :data-action="i.action"
                :data-disabled="String(!!i.disabled)"
                @click="$emit('action', i)"
              >{{ i.label }}</li>
            </template>
          </ul>`,
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

const item = (wrapper, value) => wrapper.find(`[data-value="${value}"]`);

describe('TicketActionsMenu', () => {
  it('stays closed until clicked', () => {
    expect(mountMenu().find('ul').exists()).toBe(false);
  });

  it('groups the operational actions in the requested order', async () => {
    const wrapper = await open(mountMenu());

    // Relationships, then operation, then closing - the SLA section is absent
    // without the permission, so it is not asserted here.
    const order = values(wrapper);
    expect(order.indexOf('createChild')).toBeLessThan(
      order.indexOf('transfer')
    );
    expect(order.indexOf('transfer')).toBeLessThan(order.indexOf('close'));
  });

  it('offers every relationship action', async () => {
    const items = values(await open(mountMenu()));

    expect(items).toEqual(
      expect.arrayContaining([
        'createChild',
        'setParent',
        'merge',
        'duplicate',
        'relatedConversations',
      ])
    );
  });

  describe('contextual entries', () => {
    it('offers close for an open ticket, but not reopen', async () => {
      const items = values(await open(mountMenu()));

      expect(items).toContain('close');
      expect(items).not.toContain('reopen');
    });

    // Closing IS the normal resolution now, so there is no separate action for
    // it - and the title, Empresa and Solicitante are edited in place.
    it('offers no edit, copy-link or resolve entries', async () => {
      const items = values(await open(mountMenu()));

      ['edit', 'copyLink', 'resolve'].forEach(value =>
        expect(items).not.toContain(value)
      );
    });

    it('offers reopen once the ticket is closed, and not close again', async () => {
      const items = values(
        await open(mountMenu({ ticket: ticket({ status: 'closed' }) }))
      );

      expect(items).toContain('reopen');
      expect(items).not.toContain('close');
    });

    // Cancelar foi removido do menu (fluxo do sistema so' usa Fechar), mas um
    // ticket que ja esta `cancelled` (dado legado, de antes dessa remocao)
    // ainda precisa poder ser reaberto.
    it('never offers cancel, but still offers reopen for a legacy cancelled ticket', async () => {
      const items = values(
        await open(mountMenu({ ticket: ticket({ status: 'cancelled' }) }))
      );

      expect(items).not.toContain('cancel');
      expect(items).toContain('reopen');
    });

    // Taking a ticket already owned by this user would do nothing, so the entry
    // is gone rather than present and inert.
    it('hides "assumir" when the ticket is already mine', async () => {
      const wrapper = await open(
        mountMenu({
          ticket: ticket({ assignee_id: 7 }),
          currentUserId: 7,
        })
      );

      expect(values(wrapper)).not.toContain('assignToMe');
    });

    it('offers it when the ticket belongs to somebody else', async () => {
      const wrapper = await open(
        mountMenu({ ticket: ticket({ assignee_id: 9 }), currentUserId: 7 })
      );

      expect(values(wrapper)).toContain('assignToMe');
    });

    // A terminal ticket cannot absorb another one.
    it('disables merging on a closed ticket', async () => {
      const wrapper = await open(
        mountMenu({ ticket: ticket({ status: 'closed' }) })
      );

      expect(item(wrapper, 'merge').attributes('data-disabled')).toBe('true');
    });

    it('disables merging on a ticket already grouped into another', async () => {
      const wrapper = await open(
        mountMenu({ ticket: ticket({ merged_into: { id: 2, display_id: 8 } }) })
      );

      expect(item(wrapper, 'merge').attributes('data-disabled')).toBe('true');
    });
  });

  describe('permissions', () => {
    it('disables the mutating actions without permission', async () => {
      const wrapper = await open(mountMenu({ canUpdate: false }));

      ['transfer', 'setParent', 'close'].forEach(value =>
        expect(item(wrapper, value).attributes('data-disabled')).toBe('true')
      );
    });

    it('leaves the read-only actions alone', async () => {
      const wrapper = await open(mountMenu({ canUpdate: false }));

      ['relatedConversations'].forEach(value =>
        expect(item(wrapper, value).attributes('data-disabled')).toBe('false')
      );
    });

    // The whole SLA section disappears rather than showing a permanently
    // disabled row - TicketPolicy#add_sla_hours? is stricter than update?.
    it('hides the SLA entry without the permission', async () => {
      expect(values(await open(mountMenu()))).not.toContain('addSlaHours');
    });

    it('shows it with the permission', async () => {
      const wrapper = await open(mountMenu({ canAddSlaHours: true }));

      expect(values(wrapper)).toContain('addSlaHours');
    });
  });

  // `action: 'delete'` is what DropdownMenu paints in ruby; without it the
  // destructive block reads like any other entry.
  it('marks close as destructive', async () => {
    const wrapper = await open(mountMenu());

    expect(item(wrapper, 'close').attributes('data-action')).toBe('delete');
    expect(item(wrapper, 'transfer').attributes('data-action')).not.toBe(
      'delete'
    );
  });

  it('emits the chosen action and closes', async () => {
    const wrapper = await open(mountMenu());
    await item(wrapper, 'transfer').trigger('click');

    expect(wrapper.emitted('action')).toEqual([['transfer']]);
    expect(wrapper.find('ul').exists()).toBe(false);
  });
});
