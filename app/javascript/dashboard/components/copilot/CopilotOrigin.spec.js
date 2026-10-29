import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';
import CopilotContainer from './CopilotContainer.vue';

// Ponta a ponta no navegador: a resposta do servidor ao criar o chat chega ao
// painel e vira o link "Chat aberto na conversa #X".
const state = vi.hoisted(() => ({ dispatch: vi.fn(), route: {} }));

vi.mock('vue-router', () => ({ useRoute: () => state.route }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
  useTrack: vi.fn(),
}));
vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: () => ({ isEnterprise: true }),
}));
vi.mock('dashboard/composables/useUISettings', async () => {
  const { ref: r } = await import('vue');
  return {
    useUISettings: () => ({
      uiSettings: r({ is_copilot_panel_open: true }),
      updateUISettings: vi.fn(),
    }),
  };
});
vi.mock('@vueuse/core', () => ({
  useWindowSize: () => ({ width: ref(1024) }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref: r } = await import('vue');
  const refs = {
    getCurrentUser: r({ id: 1 }),
    'captainAssistants/getRecords': r([{ id: 7 }]),
    'captainAssistants/getUIFlags': r({ fetchingList: false }),
    getCopilotAssistant: r(null),
    getSelectedChat: r({ id: 12 }),
    getCurrentAccountId: r(1),
    'accounts/isFeatureEnabledonAccount': r(() => true),
  };
  return {
    useMapGetter: key => refs[key],
    useStore: () => ({
      dispatch: state.dispatch,
      getters: {
        'copilotMessages/getMessagesByThreadId': id =>
          id
            ? [
                {
                  id: 1,
                  message_type: 'user',
                  message: { content: 'oi' },
                  copilot_thread: { id },
                },
              ]
            : [],
      },
    }),
  };
});

const montar = () =>
  mount(CopilotContainer, {
    global: {
      directives: { onClickOutside: {} },
      mocks: {
        $t: (key, params) => `${key}${params ? JSON.stringify(params) : ''}`,
      },
      stubs: {
        SidebarActionsHeader: true,
        CopilotInput: { template: '<i />' },
        CopilotAgentMessage: { template: '<p />' },
        CopilotAssistantMessage: { template: '<p />' },
        RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
      },
    },
  });

describe('DueBot mostra a origem do chat', () => {
  it('numa conversa', async () => {
    state.route = { name: 'inbox_conversation', params: { accountId: 1 } };
    state.dispatch.mockImplementation(action =>
      action === 'copilotThreads/create'
        ? Promise.resolve({
            id: 3,
            conversation_display_id: 12,
            ticket: { id: null, display_id: null },
          })
        : Promise.resolve()
    );
    const wrapper = montar();
    await wrapper
      .findComponent({ name: 'Copilot' })
      .vm.$emit('sendMessage', 'oi');
    await flushPromises();

    const link = wrapper.find('a');
    expect(link.exists()).toBe(true);
    expect(link.attributes('href')).toContain('/conversations/12');
  });

  it('num ticket', async () => {
    state.route = {
      name: 'ticket_detail',
      params: { accountId: 1, ticketId: '7' },
    };
    state.dispatch.mockImplementation(action =>
      action === 'copilotThreads/create'
        ? Promise.resolve({
            id: 4,
            conversation_display_id: null,
            ticket: { id: 7, display_id: 31 },
          })
        : Promise.resolve()
    );
    const wrapper = montar();
    await wrapper
      .findComponent({ name: 'Copilot' })
      .vm.$emit('sendMessage', 'oi');
    await flushPromises();

    expect(wrapper.find('a').attributes('href')).toContain('/tickets/7');
  });
});
