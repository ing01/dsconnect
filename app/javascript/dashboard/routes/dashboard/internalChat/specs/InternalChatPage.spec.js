import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import InternalChatPage from '../pages/InternalChatPage.vue';
import internalChat from 'dashboard/store/modules/internalChat';
import InternalChatAPI from 'dashboard/api/internalChat';

const { holder } = vi.hoisted(() => ({ holder: { push: null } }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: holder.push }),
  useRoute: () => ({ params: { accountId: 1 }, query: {} }),
}));

// Nenhuma chamada de rede nos testes; o que se verifica é que a tela conversa
// com o servidor em vez de guardar a mensagem no navegador.
vi.mock('dashboard/api/internalChat', () => ({
  default: {
    get: vi.fn(),
    getMessages: vi.fn(),
    sendMessage: vi.fn(),
    markRead: vi.fn(),
    toggleReaction: vi.fn(),
    createChannel: vi.fn(),
    openDirect: vi.fn(),
  },
}));

const AGENTS = [
  {
    id: 11,
    name: 'João Vitor',
    role: 'administrator',
    availability_status: 'online',
    confirmed: true,
  },
  {
    id: 12,
    name: 'Maria Silva',
    role: 'agent',
    availability_status: 'online',
    confirmed: true,
  },
  {
    id: 13,
    name: 'Carla Reis',
    role: 'agent',
    availability_status: 'busy',
    confirmed: true,
  },
];

const ROOMS = [
  {
    id: 5,
    kind: 'direct',
    name: null,
    userId: 12,
    memberIds: [11, 12],
    unread: 2,
  },
  {
    id: 7,
    kind: 'channel',
    name: 'suporte',
    description: 'Canal da equipe de suporte',
    memberIds: [11, 12, 13],
    unread: 0,
  },
];

const MESSAGES = [
  {
    id: 101,
    userId: 12,
    body: 'Conseguiu verificar o #32516?',
    createdAt: 1787000000,
    reactions: [],
    replyTo: null,
  },
  {
    id: 102,
    userId: 11,
    body: 'Estou olhando agora.',
    createdAt: 1787000100,
    reactions: [],
    replyTo: null,
  },
];

// O estado sai do PROPRIO modulo, clonado para cada exemplo ter o seu.
//
// Antes cada spec reescrevia a forma do estado a mao, e ela envelhecia sozinha:
// bastou o modulo ganhar `pinnedMessages` para os getters lerem `undefined` e a
// tela inteira falhar no render - o componente estava certo, os specs e que
// descreviam um estado que ja nao existia.
const freshState = () => structuredClone(internalChat.state);

const mountPage = async () => {
  holder.push = vi.fn();

  InternalChatAPI.get.mockResolvedValue({ data: { payload: ROOMS } });
  InternalChatAPI.getMessages.mockResolvedValue({
    data: { payload: MESSAGES },
  });
  InternalChatAPI.markRead.mockResolvedValue({});

  const store = createStore({
    modules: { internalChat: { ...internalChat, state: freshState() } },
    getters: {
      getCurrentUser: () => AGENTS[0],
      // A tela le o papel para decidir se oferece apagar mensagem alheia.
      getCurrentRole: () => 'agent',
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
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open() {}, close() {} },
        },
        Button: { template: '<button />' },
        OnClickOutside: { template: '<div><slot /></div>' },
      },
    },
  });

  // Duas idas ao servidor antes da tela ficar pronta - as salas e depois o
  // histórico da primeira -, então uma rodada de promessas não basta.
  await flushPromises();
  await flushPromises();
  return { wrapper, store };
};

describe('InternalChatPage', () => {
  beforeEach(() => vi.clearAllMocks());

  // O defeito que motivou esta etapa: a mensagem vivia no navegador, sumia no
  // F5 e nunca chegava ao colega.
  describe('persistence', () => {
    it('loads the rooms from the server', async () => {
      const { store } = await mountPage();

      expect(InternalChatAPI.get).toHaveBeenCalled();
      expect(
        store.getters['internalChat/getChannels'].map(room => room.name)
      ).toEqual(['suporte']);
      expect(
        store.getters['internalChat/getDirects'].map(room => room.id)
      ).toEqual([5]);
    });

    it('loads the history of the room it opens', async () => {
      const { wrapper } = await mountPage();

      expect(InternalChatAPI.getMessages).toHaveBeenCalledWith(5);
      // O `#32516` vira um elemento próprio, então o texto da mensagem não é
      // contíguo - a referência tem teste dedicado mais abaixo.
      expect(wrapper.text()).toContain('Conseguiu verificar o');
      expect(wrapper.text()).toContain('Estou olhando agora.');
    });

    it('sends the message to the server instead of keeping it locally', async () => {
      const sent = {
        id: 103,
        userId: 11,
        body: 'Vou verificar.',
        createdAt: 1787000200,
        reactions: [],
        replyTo: null,
      };
      InternalChatAPI.sendMessage.mockResolvedValue({ data: sent });

      const { wrapper, store } = await mountPage();
      await wrapper.find('textarea').setValue('Vou verificar.');
      await wrapper.find('textarea').trigger('keydown', { key: 'Enter' });
      await flushPromises();

      expect(InternalChatAPI.sendMessage).toHaveBeenCalledWith(5, {
        content: 'Vou verificar.',
        replyToId: null,
        attachments: [],
      });
      // O que entra na tela é o que o servidor devolveu, com o id dele.
      expect(
        store.getters['internalChat/getRoomById'](5).messages.at(-1)
      ).toEqual(sent);
    });

    it('tells the server the room was read', async () => {
      await mountPage();

      expect(InternalChatAPI.markRead).toHaveBeenCalledWith(5);
    });
  });

  it('separates private conversations from channels', async () => {
    const { wrapper } = await mountPage();

    expect(wrapper.findAll('aside h3').map(item => item.text())).toEqual([
      'INTERNAL_CHAT.SIDEBAR.DIRECTS',
      'INTERNAL_CHAT.SIDEBAR.CHANNELS',
    ]);
  });

  it('counts unread from what the server reported', async () => {
    const { store } = await mountPage();

    // A sala aberta e marcada como lida deixa de contar.
    expect(store.getters['internalChat/getUnreadCount']).toBe(0);
  });

  it('names the person on the other side of a direct conversation', async () => {
    const { wrapper } = await mountPage();

    expect(wrapper.text()).toContain('Maria Silva');
  });

  it('turns #32516 into a link to the ticket', async () => {
    const { wrapper } = await mountPage();

    const ticketButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('#32516'));
    expect(ticketButton.text()).toContain('Erro na emissão da nota');

    await ticketButton.trigger('click');
    expect(holder.push).toHaveBeenCalledWith(
      expect.stringContaining('/tickets/32516')
    );
  });

  it('opens a channel and loads its own history', async () => {
    const { wrapper } = await mountPage();

    const channelButton = wrapper
      .findAll('aside button')
      .find(button => button.text().includes('suporte'));
    await channelButton.trigger('click');
    await flushPromises();

    expect(InternalChatAPI.getMessages).toHaveBeenCalledWith(7);
  });

  it('asks the server to toggle a reaction', async () => {
    const reacted = {
      ...MESSAGES[0],
      reactions: [{ emoji: '👍', userIds: [11] }],
    };
    InternalChatAPI.toggleReaction.mockResolvedValue({ data: reacted });

    const { wrapper, store } = await mountPage();
    const thumbsUp = wrapper
      .findAll('button')
      .find(button => button.text() === '👍');
    await thumbsUp.trigger('click');
    await flushPromises();

    expect(InternalChatAPI.toggleReaction).toHaveBeenCalledWith(5, 101, '👍');
    const message = store.getters['internalChat/getRoomById'](5).messages[0];
    expect(message.reactions).toEqual([{ emoji: '👍', userIds: [11] }]);
  });

  // Os anexos passaram a ser gravados de verdade, entao o botao deixa de ser a
  // promessa desabilitada que era no prototipo.
  it('offers attachments now that they are stored', async () => {
    const { wrapper } = await mountPage();

    const attach = wrapper
      .findAll('button')
      .find(
        button => button.attributes('title') === 'INTERNAL_CHAT.COMPOSER.ATTACH'
      );

    expect(attach).toBeDefined();
    expect(attach.attributes('disabled')).toBeUndefined();
  });
});
