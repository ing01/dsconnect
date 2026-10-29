import { nextTick, ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import CopilotContainer from './CopilotContainer.vue';

const testState = vi.hoisted(() => ({
  dispatch: vi.fn(),
  refs: {},
  route: { name: 'inbox_conversation', params: { accountId: 1 } },
}));

vi.mock('vue-router', () => ({ useRoute: () => testState.route }));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: () => ({ isEnterprise: true }),
}));
vi.mock('dashboard/composables/useUISettings', async () => {
  const { ref: createRef } = await import('vue');
  return {
    useUISettings: () => ({
      uiSettings: createRef({ is_copilot_panel_open: true }),
      updateUISettings: vi.fn(),
    }),
  };
});
vi.mock('@vueuse/core', () => ({
  useWindowSize: () => ({ width: ref(1024) }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref: createRef } = await import('vue');
  const refs = {
    getCurrentUser: createRef({ id: 1 }),
    'captainAssistants/getRecords': createRef([{ id: 7 }]),
    'captainAssistants/getUIFlags': createRef({ fetchingList: false }),
    getCopilotAssistant: createRef(null),
    getSelectedChat: createRef({ id: 1 }),
    getLastEmailInSelectedChat: createRef({ message_type: 0 }),
    getCurrentAccountId: createRef(1),
    'accounts/isFeatureEnabledonAccount': createRef(() => true),
  };
  testState.refs = refs;

  return {
    useMapGetter: key => refs[key],
    useStore: () => ({
      dispatch: testState.dispatch,
      getters: {
        'copilotMessages/getMessagesByThreadId': threadId =>
          threadId ? [{ id: threadId }] : [],
      },
    }),
  };
});

const mountComponent = () =>
  shallowMount(CopilotContainer, {
    global: {
      directives: { onClickOutside: {} },
      stubs: {
        Copilot: {
          name: 'Copilot',
          props: ['messages'],
          template: '<div />',
        },
      },
    },
  });

describe('CopilotContainer', () => {
  beforeEach(() => {
    testState.dispatch.mockReset();
    testState.dispatch.mockResolvedValue(undefined);
    testState.refs.getSelectedChat.value = { id: 1 };
    testState.route = { name: 'inbox_conversation', params: { accountId: 1 } };
  });

  it('sends the conversation the chat was opened in', async () => {
    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Oi');
    await flushPromises();

    const [, payload] = testState.dispatch.mock.calls.find(
      ([action]) => action === 'copilotThreads/create'
    );
    expect(payload.conversation_id).toBe(1);
    expect(payload).not.toHaveProperty('ticket_id');
  });

  it('sends the ticket (and no stale conversation) when opened in a ticket', async () => {
    testState.route = {
      name: 'ticket_detail',
      params: { accountId: 1, ticketId: '42' },
    };
    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Oi');
    await flushPromises();

    const [, payload] = testState.dispatch.mock.calls.find(
      ([action]) => action === 'copilotThreads/create'
    );
    expect(payload.ticket_id).toBe('42');
    expect(payload.conversation_id).toBeNull();
  });

  it('clears the selected thread when the conversation changes', async () => {
    testState.dispatch.mockImplementation(action =>
      action === 'copilotThreads/create'
        ? Promise.resolve({ id: 99 })
        : Promise.resolve()
    );
    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Draft a reply');
    await flushPromises();
    expect(copilot.props('messages')).toEqual([{ id: 99 }]);

    testState.refs.getSelectedChat.value = { id: 2 };
    await nextTick();

    expect(copilot.props('messages')).toEqual([]);
  });

  it('ignores a thread created for a conversation that is no longer selected', async () => {
    let resolveRequest;
    testState.dispatch.mockImplementation(action => {
      if (action !== 'copilotThreads/create') return Promise.resolve();
      return new Promise(resolve => {
        resolveRequest = resolve;
      });
    });
    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Draft a reply');
    await nextTick();
    testState.refs.getSelectedChat.value = { id: 2 };
    await nextTick();
    resolveRequest({ id: 99 });
    await flushPromises();

    expect(copilot.props('messages')).toEqual([]);
  });
});
