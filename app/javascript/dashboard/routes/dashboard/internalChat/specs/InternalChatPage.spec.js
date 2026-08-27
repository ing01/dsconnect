import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import InternalChatPage from '../pages/InternalChatPage.vue';
import internalChat from 'dashboard/store/modules/internalChat';

const { holder } = vi.hoisted(() => ({ holder: { push: null } }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: holder.push }),
  useRoute: () => ({ params: { accountId: 1 }, query: {} }),
}));

// Os agentes de verdade da conta: é com eles que se conversa, e é deles que o
// diretório do Chat é montado.
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
  {
    id: 14,
    name: 'Diego Melo',
    role: 'agent',
    availability_status: 'offline',
    confirmed: true,
  },
];

// O módulo declara `state` como objeto, então registrá-lo em vários stores
// compartilharia a mesma referência e um teste veria o que o anterior semeou.
// Na aplicação ele é registrado uma única vez; aqui cada caso ganha o seu.
const freshState = () => ({
  users: [],
  channels: [],
  directs: [],
  currentUserId: null,
  isSeeded: false,
});

const buildStore = (agents = AGENTS, currentUser = AGENTS[0]) =>
  createStore({
    modules: { internalChat: { ...internalChat, state: freshState() } },
    getters: {
      getCurrentUser: () => currentUser,
      'agents/getVerifiedAgents': () => agents,
    },
    actions: {
      'agents/get': () => Promise.resolve(),
    },
  });

const mountPage = async (options = {}) => {
  holder.push = vi.fn();
  const store = buildStore(options.agents, options.currentUser);

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

  await flushPromises();
  return { wrapper, store };
};

const firstDirectId = store => store.getters['internalChat/getDirects'][0].id;

describe('InternalChatPage', () => {
  // O defeito que motivou esta mudança: o Chat listava pessoas inventadas em
  // vez dos agentes da conta, então não dava para conversar com ninguém real.
  describe('directory', () => {
    it('is built from the account agents, not from fixed names', async () => {
      const { store } = await mountPage();

      expect(
        store.getters['internalChat/getUsers'].map(user => user.id)
      ).toEqual([11, 12, 13, 14]);
    });

    it('puts the logged-in user first and keeps them out of the conversation list', async () => {
      const { store } = await mountPage();

      expect(store.getters['internalChat/getCurrentUserId']).toBe(11);
      const peers = store.getters['internalChat/getDirects'].map(d => d.userId);
      expect(peers).not.toContain(11);
    });

    it('opens a conversation with every colleague available', async () => {
      const { store } = await mountPage();

      expect(
        store.getters['internalChat/getDirects'].map(d => d.userId)
      ).toEqual([12, 13, 14]);
    });

    // Uma conta pequena não pode quebrar o roteiro de demonstração.
    it('survives an account with a single other agent', async () => {
      const { store, wrapper } = await mountPage({
        agents: AGENTS.slice(0, 2),
      });

      expect(store.getters['internalChat/getDirects']).toHaveLength(1);
      expect(wrapper.text()).toContain('Maria Silva');
    });

    it('carries the real availability of each agent', async () => {
      const { store } = await mountPage();
      const carla = store.getters['internalChat/getUserById'](13);

      expect(carla.status).toBe('busy');
    });
  });

  it('separates private conversations from channels', async () => {
    const { wrapper } = await mountPage();

    const headings = wrapper.findAll('aside h3').map(item => item.text());
    expect(headings).toEqual([
      'INTERNAL_CHAT.SIDEBAR.DIRECTS',
      'INTERNAL_CHAT.SIDEBAR.CHANNELS',
    ]);
    expect(wrapper.text()).toContain('Maria Silva');
    expect(wrapper.text()).toContain('suporte');
  });

  it('opens the first conversation on arrival', async () => {
    const { wrapper } = await mountPage();

    expect(wrapper.text()).toContain('Conseguiu verificar?');
  });

  // Abrir a sala zera o não lido, e o badge do menu acompanha.
  it('clears the unread count of the room it opens', async () => {
    const { store } = await mountPage();

    expect(
      store.getters['internalChat/getRoomById'](firstDirectId(store)).unread
    ).toBe(0);
    expect(store.getters['internalChat/getUnreadCount']).toBe(7);
  });

  it('sends a message into the open room, authored by the logged-in agent', async () => {
    const { wrapper, store } = await mountPage();

    await wrapper.find('textarea').setValue('Vou verificar agora.');
    await wrapper.find('textarea').trigger('keydown', { key: 'Enter' });

    const room = store.getters['internalChat/getRoomById'](
      firstDirectId(store)
    );
    expect(room.messages.at(-1).body).toBe('Vou verificar agora.');
    expect(room.messages.at(-1).userId).toBe(11);
  });

  it('does not send on shift+enter, which is a line break', async () => {
    const { wrapper, store } = await mountPage();
    const roomId = firstDirectId(store);
    const before =
      store.getters['internalChat/getRoomById'](roomId).messages.length;

    await wrapper.find('textarea').setValue('primeira linha');
    await wrapper.find('textarea').trigger('keydown', {
      key: 'Enter',
      shiftKey: true,
    });

    expect(
      store.getters['internalChat/getRoomById'](roomId).messages
    ).toHaveLength(before);
  });

  // A referência a um Ticket é a integração que justifica o Chat morar dentro
  // da plataforma: ela leva ao Ticket de verdade.
  it('turns #32516 into a link to the ticket', async () => {
    const { wrapper } = await mountPage();

    const ticketButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('#32516'));

    expect(ticketButton).toBeTruthy();
    expect(ticketButton.text()).toContain('Erro na emissão da nota');

    await ticketButton.trigger('click');
    expect(holder.push).toHaveBeenCalledWith(
      expect.stringContaining('/tickets/32516')
    );
  });

  it('switches to a channel and shows its messages', async () => {
    const { wrapper } = await mountPage();

    const channelButton = wrapper
      .findAll('aside button')
      .find(button => button.text().includes('suporte'));
    await channelButton.trigger('click');

    expect(wrapper.text()).toContain('O cliente da ROMAFELE retornou?');
  });

  // A menção do roteiro aponta para um agente real, e não para um nome fixo.
  it('highlights a mention of a real agent', async () => {
    const { wrapper } = await mountPage();

    const channelButton = wrapper
      .findAll('aside button')
      .find(button => button.text().includes('suporte'));
    await channelButton.trigger('click');

    const mention = wrapper
      .findAll('span')
      .find(span => span.text() === '@Carla Reis');

    expect(mention).toBeTruthy();
    expect(mention.classes().join(' ')).toContain('bg-n-blue-3');
  });

  it('records a reaction on a message', async () => {
    const { wrapper, store } = await mountPage();

    const thumbsUp = wrapper
      .findAll('button')
      .find(button => button.text() === '👍');
    await thumbsUp.trigger('click');

    const room = store.getters['internalChat/getRoomById'](
      firstDirectId(store)
    );
    const reacted = room.messages.some(message =>
      message.reactions.some(reaction => reaction.userIds.includes(11))
    );
    expect(reacted).toBe(true);
  });
});
