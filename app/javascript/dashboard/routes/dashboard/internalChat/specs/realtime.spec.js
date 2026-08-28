import { createStore } from 'vuex';
import internalChat from 'dashboard/store/modules/internalChat';
import InternalChatAPI from 'dashboard/api/internalChat';

vi.mock('dashboard/api/internalChat', () => ({
  default: { markRead: vi.fn(() => Promise.resolve()) },
}));

const ME = 11;

const buildStore = ({ activeRoomId = null, isLoaded = true } = {}) =>
  createStore({
    modules: {
      internalChat: {
        ...internalChat,
        state: {
          users: [],
          currentUserId: ME,
          activeRoomId,
          uiFlags: {},
          rooms: [
            {
              id: 5,
              kind: 'direct',
              userId: 12,
              unread: 0,
              isLoaded,
              messages: isLoaded
                ? [{ id: 101, userId: 12, body: 'ola', reactions: [] }]
                : [],
            },
          ],
        },
      },
    },
  });

const incoming = (overrides = {}) => ({
  id: 102,
  userId: 12,
  body: 'chegou agora',
  createdAt: 1787000000,
  reactions: [],
  replyTo: null,
  ...overrides,
});

const room = store => store.getters['internalChat/getRoomById'](5);

// Uma mensagem que chega pelo ActionCable enquanto a pessoa esta na tela.
describe('internalChat realtime', () => {
  beforeEach(() => vi.clearAllMocks());

  it('adds the message that arrives for a loaded room', () => {
    const store = buildStore();

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming(),
    });

    expect(room(store).messages.map(m => m.id)).toEqual([101, 102]);
  });

  it('counts it as unread when the room is not the open one', () => {
    const store = buildStore({ activeRoomId: 7 });

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming(),
    });

    expect(room(store).unread).toBe(1);
    expect(store.getters['internalChat/getUnreadCount']).toBe(1);
    expect(InternalChatAPI.markRead).not.toHaveBeenCalled();
  });

  // Com a sala à vista, ler é imediato - e o servidor precisa saber.
  it('marks the room read when it is the open one', () => {
    const store = buildStore({ activeRoomId: 5 });

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming(),
    });

    expect(room(store).unread).toBe(0);
    expect(InternalChatAPI.markRead).toHaveBeenCalledWith(5);
  });

  // A própria mensagem pode voltar por outra aba da mesma pessoa.
  it('never counts the person own message as unread', () => {
    const store = buildStore({ activeRoomId: 7 });

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming({ userId: ME }),
    });

    expect(room(store).unread).toBe(0);
  });

  it('does not duplicate a message it already has', () => {
    const store = buildStore();

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming({ id: 101, body: 'ola' }),
    });

    expect(room(store).messages).toHaveLength(1);
  });

  // Reagir chega como mensagem alterada: o registro é substituído.
  it('replaces a message it already has, keeping the order', () => {
    const store = buildStore();

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming({
        id: 101,
        body: 'ola',
        reactions: [{ emoji: '👍', userIds: [12] }],
      }),
    });

    expect(room(store).messages[0].reactions).toEqual([
      { emoji: '👍', userIds: [12] },
    ]);
  });

  // Sem o histórico carregado, inserir a mensagem deixaria um recado solto
  // sem nada antes dele.
  it('does not drop a lone message into a room never opened', () => {
    const store = buildStore({ activeRoomId: 7, isLoaded: false });

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 5,
      message: incoming(),
    });

    expect(room(store).messages).toHaveLength(0);
    // Mas o não lido sobe, porque a sala recebeu algo.
    expect(room(store).unread).toBe(1);
  });

  it('ignores a room the person is not in', () => {
    const store = buildStore();

    store.dispatch('internalChat/applyRealtimeMessage', {
      channelId: 999,
      message: incoming(),
    });

    expect(room(store).messages).toHaveLength(1);
  });
});
