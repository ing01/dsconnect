import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import ConversationItem from '../ConversationItem.vue';

const { dispatch } = vi.hoisted(() => ({ dispatch: vi.fn() }));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch,
    getters: {
      'inboxes/getInbox': () => ({ id: 5, channel_type: 'Channel::Email' }),
      'contacts/getContact': () => ({}),
    },
  }),
  useMapGetter: name => {
    if (name === 'getSelectedChat') return ref({});
    if (name === 'inboxes/getInboxes') return ref([]);
    if (name === 'getCurrentAccountId') return ref(1);
    return ref(null);
  },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ name: 'email_conversations', params: {} }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const noop = () => {};
const provide = {
  selectConversation: noop,
  deSelectConversation: noop,
  assignAgent: noop,
  assignTeam: noop,
  assignLabels: noop,
  removeLabels: noop,
  updateConversationStatus: noop,
  toggleContextMenu: noop,
  markAsUnread: noop,
  markAsRead: noop,
  assignPriority: noop,
  isConversationSelected: () => false,
};

const mountItem = () =>
  mount(ConversationItem, {
    attachTo: document.body,
    props: { source: { id: 77, inbox_id: 5, meta: {}, labels: [] } },
    global: {
      provide,
      stubs: {
        ConversationCard: {
          name: 'ConversationCard',
          template:
            '<div class="card" @contextmenu="$emit(\'contextmenu\', $event)" />',
        },
        ConversationCardExpanded: true,
        ContextMenu: { template: '<div class="ctx"><slot /></div>' },
        ConversationContextMenu: {
          name: 'ConversationContextMenu',
          template: '<button class="delete" @click="$emit(\'delete\')" />',
        },
        'woot-delete-modal': {
          props: { onConfirm: Function },
          template: '<button class="confirm-delete" @click="onConfirm" />',
        },
      },
    },
  });

describe('ConversationItem - excluir e-mail', () => {
  afterEach(() => {
    document.body.innerHTML = '';
    dispatch.mockReset();
  });

  // Cada linha da lista virtual tem `contain: layout`: a confirmacao dentro
  // dela ficava presa e escondida. Ela precisa ir para o <body>.
  it('renders the confirmation outside the list row, on the body', async () => {
    const wrapper = mountItem();
    await wrapper.find('.card').trigger('contextmenu');
    await wrapper.find('.delete').trigger('click');

    // Esta na pagina, mas nao dentro do proprio componente (a linha).
    expect(document.body.querySelector('.confirm-delete')).not.toBeNull();
    expect(wrapper.find('.confirm-delete').exists()).toBe(false);
    wrapper.unmount();
  });

  it('asks the server to delete once confirmed', async () => {
    const wrapper = mountItem();
    await wrapper.find('.card').trigger('contextmenu');
    await wrapper.find('.delete').trigger('click');

    document.body.querySelector('.confirm-delete').click();
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'conversations/deleteConversation',
      77
    );
    wrapper.unmount();
  });
});
