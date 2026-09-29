import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import InternalChatPage from '../pages/InternalChatPage.vue';
import internalChat from 'dashboard/store/modules/internalChat';
import InternalChatAPI from 'dashboard/api/internalChat';

// Tres coisas que a tela passou a oferecer, e que antes eram botoes mortos ou um
// aviso do navegador:
//
//  - a confirmacao de apagar e um DIALOGO do sistema, nao o `window.confirm`;
//  - o canal pode ser editado pelos tres pontos e pelo botao direito;
//  - o botao de membros abre a listagem lateral.
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: { accountId: 1 }, query: {} }),
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
  { id: 13, name: 'Carla Reis', role: 'agent', confirmed: true },
];

const CANAL = {
  id: 7,
  kind: 'channel',
  name: 'comunicados',
  description: 'Avisos da empresa',
  memberIds: [11, 12, 13],
  moderatorIds: [12],
  postingPolicy: 'moderators',
  pinned: true,
  canPost: true,
  unread: 0,
};

const MESSAGES = [
  { id: 101, userId: 11, body: 'minha mensagem', createdAt: 1, reactions: [] },
  { id: 102, userId: 12, body: 'de outra pessoa', createdAt: 2, reactions: [] },
];

const freshState = () => ({
  users: [],
  rooms: [],
  currentUserId: null,
  uiFlags: {
    isFetchingRooms: false,
    isFetchingMessages: false,
    isSending: false,
  },
});

// O `Dialog` real depende de `<dialog>`, que o jsdom nao implementa; este duble
// guarda se foi aberto, que e o que os exemplos perguntam.
const DialogStub = {
  props: ['title', 'description', 'confirmButtonLabel', 'type'],
  emits: ['confirm'],
  data: () => ({ aberto: false }),
  methods: {
    open() {
      this.aberto = true;
    },
    close() {
      this.aberto = false;
    },
  },
  template:
    '<div v-if="aberto" class="dialogo" :data-titulo="title"><slot /><button class="confirmar" @click="$emit(\'confirm\')" /></div>',
};

const montar = async ({ role = 'administrator' } = {}) => {
  InternalChatAPI.get.mockResolvedValue({ data: { payload: [CANAL] } });
  InternalChatAPI.getMessages.mockResolvedValue({
    data: { payload: MESSAGES },
  });
  InternalChatAPI.markRead.mockResolvedValue({});
  InternalChatAPI.deleteMessage.mockResolvedValue({});
  InternalChatAPI.updateChannel.mockResolvedValue({ data: CANAL });

  const store = createStore({
    modules: { internalChat: { ...internalChat, state: freshState() } },
    getters: {
      getCurrentUser: () => AGENTS[0],
      getCurrentRole: () => role,
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
        Dialog: DialogStub,
        Button: { template: '<button />' },
        OnClickOutside: { template: '<div><slot /></div>' },
      },
    },
  });
  await flushPromises();

  // Abrir o canal e o ponto de partida de tudo aqui.
  await wrapper
    .findAll('button')
    .find(b => b.text().includes('comunicados'))
    ?.trigger('click');
  await flushPromises();

  return { wrapper, store };
};

const porTitulo = (wrapper, titulo) =>
  wrapper.findAll('.dialogo').find(d => d.attributes('data-titulo') === titulo);

const botaoComTitulo = (wrapper, titulo) =>
  wrapper.findAll('button').find(b => b.attributes('title') === titulo);

describe('apagar mensagem', () => {
  // O pedido: a confirmacao aparece como modal, nao como o aviso do navegador.
  it('asks in a dialog, never through the browser confirm', async () => {
    const confirm = vi.fn(() => true);
    vi.stubGlobal('confirm', confirm);
    const { wrapper } = await montar();

    await wrapper
      .find('button[title="INTERNAL_CHAT.MESSAGE.DELETE"]')
      .trigger('click');

    expect(confirm).not.toHaveBeenCalled();
    expect(porTitulo(wrapper, 'INTERNAL_CHAT.MESSAGE.DELETE_TITLE')).not.toBe(
      undefined
    );
    vi.unstubAllGlobals();
  });

  // Abrir o dialogo nao apaga nada: so a confirmacao apaga.
  it('deletes nothing until the dialog is confirmed', async () => {
    const { wrapper } = await montar();

    await wrapper
      .find('button[title="INTERNAL_CHAT.MESSAGE.DELETE"]')
      .trigger('click');

    expect(InternalChatAPI.deleteMessage).not.toHaveBeenCalled();

    await porTitulo(wrapper, 'INTERNAL_CHAT.MESSAGE.DELETE_TITLE')
      .find('button.confirmar')
      .trigger('click');
    await flushPromises();

    expect(InternalChatAPI.deleteMessage).toHaveBeenCalledWith(7, 101);
  });
});

describe('editar o canal', () => {
  it('opens the edit dialog from the three dots', async () => {
    const { wrapper } = await montar();

    await botaoComTitulo(wrapper, 'INTERNAL_CHAT.HEADER.MORE').trigger('click');
    await wrapper
      .findAll('button')
      .find(b => b.text() === 'INTERNAL_CHAT.HEADER.EDIT_CHANNEL')
      .trigger('click');

    expect(porTitulo(wrapper, 'INTERNAL_CHAT.EDIT_CHANNEL.TITLE')).not.toBe(
      undefined
    );
  });

  it('opens it from a right click on the channel in the sidebar', async () => {
    const { wrapper } = await montar();

    const item = wrapper
      .findAll('button')
      .find(b => b.text().includes('comunicados'));
    await item.trigger('contextmenu');
    await wrapper
      .findAll('button')
      .find(b => b.text() === 'INTERNAL_CHAT.SIDEBAR.EDIT_CHANNEL')
      .trigger('click');

    expect(porTitulo(wrapper, 'INTERNAL_CHAT.EDIT_CHANNEL.TITLE')).not.toBe(
      undefined
    );
  });

  // Editar o canal e decisao sobre o canal da empresa: agente comum nao recebe
  // nem o menu nem o atalho do botao direito.
  it('offers neither to a plain agent', async () => {
    const { wrapper } = await montar({ role: 'agent' });

    expect(botaoComTitulo(wrapper, 'INTERNAL_CHAT.HEADER.MORE')).toBe(
      undefined
    );

    const item = wrapper
      .findAll('button')
      .find(b => b.text().includes('comunicados'));
    await item.trigger('contextmenu');

    expect(
      wrapper
        .findAll('button')
        .find(b => b.text() === 'INTERNAL_CHAT.SIDEBAR.EDIT_CHANNEL')
    ).toBe(undefined);
  });
});

describe('a listagem de membros', () => {
  const abrirMembros = wrapper =>
    botaoComTitulo(wrapper, 'INTERNAL_CHAT.HEADER.MEMBERS_TITLE').trigger(
      'click'
    );

  // O botao de membros nao abria nada: mostrava a contagem e ficava ali.
  it('opens on the members button and names everyone in the channel', async () => {
    const { wrapper } = await montar();

    await abrirMembros(wrapper);

    const painel = wrapper.find('aside.w-64');
    expect(painel.exists()).toBe(true);
    expect(painel.text()).toContain('Maria Silva');
    expect(painel.text()).toContain('Carla Reis');
  });

  it('closes again on the same button', async () => {
    const { wrapper } = await montar();

    await abrirMembros(wrapper);
    expect(wrapper.find('aside.w-64').exists()).toBe(true);

    await abrirMembros(wrapper);

    expect(wrapper.find('aside.w-64').exists()).toBe(false);
  });

  // Num canal de aviso a lista responde a segunda pergunta: quem, desses,
  // escreve.
  it('marks who is authorized to write in a restricted channel', async () => {
    const { wrapper } = await montar();

    await abrirMembros(wrapper);

    expect(wrapper.find('aside.w-64').text()).toContain(
      'INTERNAL_CHAT.MEMBERS_PANEL.RESTRICTED_HINT'
    );
  });
});
