import { mount, flushPromises } from '@vue/test-utils';
import { reactive, nextTick } from 'vue';
import { createStore } from 'vuex';
import InternalChatPage from '../pages/InternalChatPage.vue';
import internalChat from 'dashboard/store/modules/internalChat';
import InternalChatAPI from 'dashboard/api/internalChat';

// O defeito relatado: clicar na notificação do Chat Interno abria a tela, mas não
// a conversa de onde veio o aviso.
//
// O servidor sempre mandou a sala em `?room=`. O que faltava era do lado de cá:
// a query chega como TEXTO, e `getRoomById` compara com `===` - "7" nunca
// encontrava a sala 7, então a tela abria sem nada selecionado.
//
// E havia um segundo caso: com o Chat já aberto, o router só troca a query e o
// componente não remonta, então nem o código do `onMounted` rodava de novo.
const { rota } = vi.hoisted(() => ({
  rota: { params: { accountId: 1 }, query: {} },
}));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => rota,
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/internalChat', () => ({
  default: {
    get: vi.fn(),
    getMessages: vi.fn(),
    sendMessage: vi.fn(),
    markRead: vi.fn(),
    toggleReaction: vi.fn(),
    createChannel: vi.fn(),
    updateChannel: vi.fn(),
    deleteMessage: vi.fn(),
    openDirect: vi.fn(),
  },
}));

const AGENTS = [
  { id: 11, name: 'João Vitor', role: 'administrator', confirmed: true },
  { id: 12, name: 'Maria Silva', role: 'agent', confirmed: true },
];

const ROOMS = [
  { id: 5, kind: 'direct', name: null, userId: 12, memberIds: [11, 12] },
  {
    id: 7,
    kind: 'channel',
    name: 'comunicados',
    memberIds: [11, 12],
    canPost: true,
  },
];

const MENSAGENS = {
  5: [{ id: 51, userId: 12, body: 'na conversa', createdAt: 1, reactions: [] }],
  7: [{ id: 71, userId: 12, body: 'no canal', createdAt: 1, reactions: [] }],
};

const freshState = () => ({
  users: [],
  rooms: [],
  currentUserId: null,
  activeRoomId: null,
  uiFlags: {
    isFetchingRooms: false,
    isFetchingMessages: false,
    isSending: false,
  },
});

const montar = async query => {
  // Reativo: o observador da query é justamente o que o segundo caso exercita.
  Object.assign(rota, { params: { accountId: 1 }, query: reactive({}) });
  Object.assign(rota.query, query);

  InternalChatAPI.get.mockResolvedValue({ data: { payload: ROOMS } });
  InternalChatAPI.getMessages.mockImplementation(roomId =>
    Promise.resolve({ data: { payload: MENSAGENS[Number(roomId)] || [] } })
  );
  InternalChatAPI.markRead.mockResolvedValue({});

  const store = createStore({
    modules: { internalChat: { ...internalChat, state: freshState() } },
    getters: {
      getCurrentUser: () => AGENTS[0],
      getCurrentRole: () => 'administrator',
      'agents/getVerifiedAgents': () => AGENTS,
    },
    actions: { 'agents/get': () => Promise.resolve() },
  });

  const wrapper = mount(InternalChatPage, {
    global: {
      plugins: [store],
      stubs: {
        Avatar: { props: ['name'], template: '<span>{{ name }}</span>' },
        Icon: true,
        Dialog: { template: '<div />', methods: { open() {}, close() {} } },
        Button: { template: '<button />' },
        OnClickOutside: { template: '<div><slot /></div>' },
      },
    },
  });
  await flushPromises();
  return { wrapper, store };
};

describe('abrir pela notificação', () => {
  // O caso central: a query chega como texto, e a sala tem id numérico.
  it('opens the room the notification points at, even as a string', async () => {
    const { wrapper, store } = await montar({ room: '7' });

    expect(store.state.internalChat.activeRoomId).toBe(7);
    expect(wrapper.text()).toContain('no canal');
  });

  it('opens a direct conversation the same way', async () => {
    const { wrapper } = await montar({ room: '5' });

    expect(wrapper.text()).toContain('na conversa');
  });

  // Sem `?room=` a tela segue como sempre: abre a primeira sala.
  it('falls back to the first room when the notification says nothing', async () => {
    const { store } = await montar({});

    expect(store.state.internalChat.activeRoomId).toBe(5);
  });

  // O segundo caso: o Chat já estava aberto. O router só troca a query, o
  // componente não remonta, e sem o observador o clique não levava a nada.
  it('switches rooms when the notification arrives with the chat already open', async () => {
    const { wrapper, store } = await montar({ room: '5' });
    expect(store.state.internalChat.activeRoomId).toBe(5);

    rota.query.room = '7';
    await nextTick();
    await flushPromises();

    expect(store.state.internalChat.activeRoomId).toBe(7);
    expect(wrapper.text()).toContain('no canal');
  });

  // Clicar no aviso da sala que já está aberta não recarrega a conversa.
  it('does nothing when the room is already the open one', async () => {
    await montar({ room: '7' });
    InternalChatAPI.getMessages.mockClear();

    rota.query.room = '7';
    await nextTick();
    await flushPromises();

    expect(InternalChatAPI.getMessages).not.toHaveBeenCalled();
  });

  // Query estragada - alguém editou a URL - não pode derrubar a tela.
  it('survives a room that is not a number', async () => {
    const { wrapper, store } = await montar({ room: 'abc' });

    expect(store.state.internalChat.activeRoomId).toBeNull();
    expect(wrapper.text()).toContain('INTERNAL_CHAT.NO_ROOM');
  });
});
