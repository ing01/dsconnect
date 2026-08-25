import { mount, flushPromises } from '@vue/test-utils';
import TicketsList from '../TicketsList.vue';

const { dispatch, holder, getByConversation, unlinkConversation } = vi.hoisted(
  () => ({
    dispatch: vi.fn(),
    holder: {},
    getByConversation: vi.fn(),
    unlinkConversation: vi.fn(),
  })
);

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.accountId = ref(1);
  holder.chat = ref({ meta: { sender: { id: 3, company_id: 7 } } });
  return {
    useStore: () => ({ dispatch, getters: {} }),
    useMapGetter: name =>
      name === 'getSelectedChat' ? holder.chat : holder.accountId,
  };
});

vi.mock('dashboard/api/tickets', () => ({
  default: { getByConversation, unlinkConversation, linkConversation: vi.fn() },
}));

const push = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const TICKETS = [
  { id: 11, display_id: 32516, title: 'Erro na emissao NF' },
  { id: 12, display_id: 32540, title: 'Configuracao estoque' },
];

const mountPanel = async (props = {}) => {
  const wrapper = mount(TicketsList, {
    props: { conversationId: 42, isOpen: true, ...props },
    global: {
      stubs: {
        Icon: true,
        Spinner: true,
        // The shared creation form; the panel only supplies its context and
        // reacts to what it emits.
        TicketCreateDialog: {
          name: 'TicketCreateDialog',
          props: { context: Object, conversationId: [Number, String] },
          template: '<div class="create-form" />',
        },
        LinkExistingTicket: {
          name: 'LinkExistingTicket',
          props: { companyId: [Number, String], linkedTicketIds: Array },
          template: '<div class="link-form" />',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

const panel = wrapper => wrapper.find('.absolute');
// The submenu header echoes the same label, so the two are told apart by their
// marker rather than by their text.
const openAddMenu = async wrapper => {
  await wrapper.find('[data-role="add"]').trigger('click');
  return wrapper;
};
const goBack = async wrapper => {
  await wrapper.find('[data-role="back"]').trigger('click');
  return wrapper;
};
const actionButton = (wrapper, value) =>
  wrapper.find(`[data-action="${value}"]`);
const choose = async (wrapper, value) => {
  await openAddMenu(wrapper);
  await actionButton(wrapper, value).trigger('click');
  await flushPromises();
  return wrapper;
};

// `woot-modal` is registered by the app, not by the test, so in here it renders
// its slot no matter what - both forms are always in the tree. What the
// component actually decides is which modal it marks as shown, so that is what
// gets asserted.
const openModalHtml = wrapper =>
  wrapper
    .findAll('[show="true"]')
    .map(node => node.html())
    .join('');

const createForm = wrapper =>
  wrapper.findComponent({ name: 'TicketCreateDialog' });
const linkForm = wrapper =>
  wrapper.findComponent({ name: 'LinkExistingTicket' });

describe('TicketsList panel', () => {
  beforeEach(() => {
    dispatch.mockReset();
    push.mockReset();
    unlinkConversation.mockReset().mockResolvedValue({});
    getByConversation.mockResolvedValue({ data: { payload: TICKETS } });
    holder.chat.value = { meta: { sender: { id: 3, company_id: 7 } } };
  });

  describe('the panel itself', () => {
    it('renders nothing until it is opened', async () => {
      const wrapper = await mountPanel({ isOpen: false });

      expect(panel(wrapper).exists()).toBe(false);
    });

    it('lists the linked tickets by number and title', async () => {
      const wrapper = await mountPanel();

      expect(wrapper.text()).toContain('#32516');
      expect(wrapper.text()).toContain('Erro na emissao NF');
      expect(wrapper.text()).toContain('#32540');
    });

    it('says so when nothing is linked', async () => {
      getByConversation.mockResolvedValue({ data: { payload: [] } });
      const wrapper = await mountPanel();

      expect(wrapper.text()).toContain('NO_LINKED_TICKETS');
    });

    // Only the list scrolls, and only once it outgrows its cap - the panel
    // itself never does.
    it('caps the list height rather than the panel', async () => {
      const wrapper = await mountPanel();

      expect(wrapper.find('ul').classes()).toEqual(
        expect.arrayContaining(['max-h-56', 'overflow-y-auto'])
      );
    });

    it('reports the count it loaded, so the badge costs no request', async () => {
      const wrapper = await mountPanel();

      expect(wrapper.emitted('count').at(-1)).toEqual([2]);
    });

    it('opens the ticket that was clicked and closes the panel', async () => {
      const wrapper = await mountPanel();

      await wrapper.findAll('button')[0].trigger('click');

      expect(push).toHaveBeenCalledTimes(1);
      expect(push.mock.calls[0][0]).toContain('/tickets/11');
      expect(wrapper.emitted('close')).toBeTruthy();
    });

    it('unlinks without leaving the panel', async () => {
      const wrapper = await mountPanel();

      await wrapper
        .find('[aria-label="TICKET.CONVERSATION_PANEL.UNLINK"]')
        .trigger('click');
      await flushPromises();

      expect(unlinkConversation).toHaveBeenCalledWith(11, 42);
      expect(wrapper.emitted('count').at(-1)).toEqual([1]);
      expect(wrapper.emitted('close')).toBeFalsy();
    });
  });

  describe('the add menu', () => {
    it('is a second level, not a separate popup', async () => {
      const wrapper = await openAddMenu(await mountPanel());

      expect(panel(wrapper).exists()).toBe(true);
      expect(wrapper.text()).not.toContain('#32516');
    });

    it('offers exactly the four flows', async () => {
      const wrapper = await openAddMenu(await mountPanel());

      expect(
        wrapper.findAll('[data-action]').map(b => b.attributes('data-action'))
      ).toEqual([
        'createKeepOpen',
        'linkKeepOpen',
        'createAndResolve',
        'linkAndResolve',
      ]);
    });

    it('goes back to the list', async () => {
      const wrapper = await openAddMenu(await mountPanel());

      await goBack(wrapper);

      expect(wrapper.text()).toContain('#32516');
      expect(wrapper.emitted('close')).toBeFalsy();
    });

    // Reopening starts on the list: the add menu is somewhere the agent chose
    // to go, not a state that outlives the panel.
    it('reopens on the list', async () => {
      const wrapper = await openAddMenu(await mountPanel());

      await wrapper.setProps({ isOpen: false });
      await wrapper.setProps({ isOpen: true });

      expect(wrapper.text()).toContain('#32516');
    });
  });

  describe('choosing a flow', () => {
    // The same form the Kanban and the child flow use, handed the Empresa,
    // Solicitante and Conversation the chat already knows.
    it('opens the shared creation form with the chat context', async () => {
      const wrapper = await choose(await mountPanel(), 'createKeepOpen');

      expect(createForm(wrapper).props('conversationId')).toBe(42);
      expect(createForm(wrapper).props('context')).toMatchObject({
        companyId: 7,
        contactId: 3,
      });
      expect(openModalHtml(wrapper)).toContain('create-form');
      expect(openModalHtml(wrapper)).not.toContain('link-form');
    });

    // Without an Empresa on the contact there is nothing valid to pre-fill, so
    // the form asks for it instead of carrying a mismatched pair.
    it('leaves the Solicitante out when the contact has no Empresa', async () => {
      holder.chat.value = { meta: { sender: { id: 3 } } };
      const wrapper = await choose(await mountPanel(), 'createKeepOpen');

      expect(createForm(wrapper).props('context')).toMatchObject({
        companyId: null,
        contactId: null,
      });
    });

    it('opens the picker for the linking flows', async () => {
      const wrapper = await choose(await mountPanel(), 'linkKeepOpen');

      expect(openModalHtml(wrapper)).toContain('link-form');
      expect(openModalHtml(wrapper)).not.toContain('create-form');
    });

    it('closes the panel once a flow is chosen', async () => {
      const wrapper = await choose(await mountPanel(), 'createKeepOpen');

      expect(wrapper.emitted('close')).toBeTruthy();
    });

    // Only that Empresa's tickets may be linked, and the Empresa comes from the
    // conversation's contact.
    it('scopes the picker to the contact Empresa', async () => {
      const wrapper = await choose(await mountPanel(), 'linkAndResolve');

      expect(linkForm(wrapper).props('companyId')).toBe(7);
    });

    it('passes no Empresa when the contact has none', async () => {
      holder.chat.value = { meta: { sender: { id: 3 } } };
      const wrapper = await choose(await mountPanel(), 'linkKeepOpen');

      expect(linkForm(wrapper).props('companyId')).toBeNull();
    });
  });

  describe('what happens after the ticket is linked', () => {
    const finish = async (wrapper, form) => {
      await form(wrapper).vm.$emit(form === createForm ? 'created' : 'linked');
      await flushPromises();
    };

    it('leaves the conversation open for "manter chat em andamento"', async () => {
      const wrapper = await choose(await mountPanel(), 'createKeepOpen');

      await finish(wrapper, createForm);

      expect(dispatch).not.toHaveBeenCalledWith(
        'toggleStatus',
        expect.anything()
      );
    });

    it('resolves it for "finalizar e abrir ticket"', async () => {
      const wrapper = await choose(await mountPanel(), 'createAndResolve');

      await finish(wrapper, createForm);

      expect(dispatch).toHaveBeenCalledWith('toggleStatus', {
        conversationId: 42,
        status: 'resolved',
      });
    });

    it('resolves it for "finalizar e adicionar a ticket existente"', async () => {
      const wrapper = await choose(await mountPanel(), 'linkAndResolve');

      await finish(wrapper, linkForm);

      expect(dispatch).toHaveBeenCalledWith('toggleStatus', {
        conversationId: 42,
        status: 'resolved',
      });
    });

    // The conversation must survive a flow the agent abandoned - closing the
    // form is not the same as the ticket having been created.
    it('resolves nothing when the form is closed without linking', async () => {
      const wrapper = await choose(await mountPanel(), 'createAndResolve');

      await createForm(wrapper).vm.$emit('close');
      await flushPromises();

      expect(dispatch).not.toHaveBeenCalledWith(
        'toggleStatus',
        expect.anything()
      );
    });

    it('does not carry the resolve intent into the next flow', async () => {
      const wrapper = await mountPanel();
      await choose(wrapper, 'createAndResolve');
      await createForm(wrapper).vm.$emit('close');
      await flushPromises();

      // Reopening the panel is what resets it back to the list.
      await wrapper.setProps({ isOpen: false });
      await wrapper.setProps({ isOpen: true });
      await choose(wrapper, 'createKeepOpen');
      await finish(wrapper, createForm);

      expect(dispatch).not.toHaveBeenCalledWith(
        'toggleStatus',
        expect.anything()
      );
    });
  });
});
