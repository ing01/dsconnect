import { mount, flushPromises } from '@vue/test-utils';
import TicketContactSelect from '../TicketContactSelect.vue';

const { listContacts } = vi.hoisted(() => ({ listContacts: vi.fn() }));

vi.mock('dashboard/api/companies', () => ({
  default: { listContacts },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const CONTACTS = {
  7: [
    { id: 1, name: 'Jose', email: 'jose@romafele.com' },
    { id: 2, name: 'Maria', email: 'maria@romafele.com' },
  ],
  8: [{ id: 3, name: 'Carlos', email: 'carlos@abc.com' }],
};

const mountSelect = (props = {}) =>
  mount(TicketContactSelect, {
    props: { companyId: 7, ...props },
    global: {
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Icon: true,
        DropdownMenu: {
          // Named so the search test can reach it with findComponent.
          name: 'DropdownMenu',
          props: { menuItems: { type: Array, default: () => [] } },
          emits: ['action', 'search'],
          template: `<ul>
            <li
              v-for="i in menuItems"
              :key="i.value"
              :data-value="i.value"
              @click="$emit('action', i)"
            >{{ i.label }}</li>
          </ul>`,
        },
      },
    },
  });

const trigger = wrapper => wrapper.find('button');

const openMenu = async wrapper => {
  await trigger(wrapper).trigger('click');
  await flushPromises();
  return wrapper;
};

const names = wrapper => wrapper.findAll('li').map(li => li.text());

describe('TicketContactSelect', () => {
  beforeEach(() => {
    listContacts.mockReset();
    listContacts.mockImplementation(companyId =>
      Promise.resolve({ data: { payload: CONTACTS[companyId] || [] } })
    );
  });

  // The Solicitante is a person AT the Empresa, so the list comes from the
  // company's own contacts through the real endpoint - not from a name filter.
  it('lists only the contacts of the ticket Empresa', async () => {
    const wrapper = await openMenu(mountSelect());

    expect(listContacts).toHaveBeenCalledWith(7, 1, '');
    expect(names(wrapper)).toEqual(['Jose', 'Maria']);
  });

  it('asks the server to narrow the list instead of filtering locally', async () => {
    const wrapper = await openMenu(mountSelect());

    await wrapper
      .findComponent({ name: 'DropdownMenu' })
      .vm.$emit('search', 'mar');
    await flushPromises();

    expect(listContacts).toHaveBeenLastCalledWith(7, 1, 'mar');
  });

  describe('without an Empresa', () => {
    it('is disabled', () => {
      const wrapper = mountSelect({ companyId: null });

      expect(trigger(wrapper).attributes('disabled')).toBeDefined();
    });

    it('says an Empresa is needed first', () => {
      const wrapper = mountSelect({ companyId: null });

      expect(wrapper.text()).toContain('CONTACT_DIALOG.NEEDS_COMPANY');
    });

    it('asks the server for nothing', async () => {
      await openMenu(mountSelect({ companyId: null }));

      expect(listContacts).not.toHaveBeenCalled();
    });
  });

  describe('when the Empresa changes', () => {
    it('reloads the contacts of the new one', async () => {
      const wrapper = await openMenu(mountSelect());

      await wrapper.setProps({ companyId: 8 });
      await openMenu(wrapper);

      expect(listContacts).toHaveBeenLastCalledWith(8, 1, '');
      expect(names(wrapper)).toEqual(['Carlos']);
    });

    // Keeping Jose selected under EMPRESA ABC is exactly the pair the backend
    // refuses, so the value is dropped rather than carried over.
    it('clears a requester who does not belong to it', async () => {
      const wrapper = await openMenu(mountSelect({ modelValue: 1 }));

      await wrapper.setProps({ companyId: 8 });

      expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([null]);
    });

    it('does not clear anything on the first render', async () => {
      const wrapper = mountSelect({ modelValue: 1 });
      await flushPromises();

      expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    });
  });

  it('emits the chosen contact', async () => {
    const wrapper = await openMenu(mountSelect());

    await wrapper.find('[data-value="2"]').trigger('click');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([2]);
    expect(wrapper.emitted('select').at(-1)[0].name).toBe('Maria');
  });
});
