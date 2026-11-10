import { actions } from '../../internalChat';
import types from '../../../mutation-types';
import InternalChatAPI from 'dashboard/api/internalChat';

// Marcar uma mensagem como nao lida, para responder depois.
vi.mock('dashboard/api/internalChat', () => ({
  default: { markMessageUnread: vi.fn(), markRoomUnread: vi.fn() },
}));

describe('marcar mensagem como nao lida', () => {
  it('guarda o nao lido que o servidor recontou, para o contador do menu', async () => {
    InternalChatAPI.markMessageUnread.mockResolvedValue({
      data: { unread: 3 },
    });
    const commit = vi.fn();

    await actions.markMessageUnread({ commit }, { roomId: 5, messageId: 9 });

    expect(InternalChatAPI.markMessageUnread).toHaveBeenCalledWith(5, 9);
    expect(commit).toHaveBeenCalledWith(types.SET_INTERNAL_CHAT_UNREAD, {
      roomId: 5,
      unread: 3,
    });
  });

  it('deixa de tratar a sala como aberta, para a proxima mensagem nao ler tudo de novo', async () => {
    InternalChatAPI.markMessageUnread.mockResolvedValue({
      data: { unread: 1 },
    });
    const commit = vi.fn();

    await actions.markMessageUnread({ commit }, { roomId: 5, messageId: 9 });

    expect(commit).toHaveBeenCalledWith(
      types.SET_INTERNAL_CHAT_ACTIVE_ROOM,
      null
    );
  });
});

describe('marcar a sala como nao lida', () => {
  it('guarda o nao lido e fecha a sala se era a aberta', async () => {
    InternalChatAPI.markRoomUnread.mockResolvedValue({ data: { unread: 1 } });
    const commit = vi.fn();

    await actions.markRoomUnread({ commit, state: { activeRoomId: 5 } }, 5);

    expect(commit).toHaveBeenCalledWith(types.SET_INTERNAL_CHAT_UNREAD, {
      roomId: 5,
      unread: 1,
    });
    expect(commit).toHaveBeenCalledWith(
      types.SET_INTERNAL_CHAT_ACTIVE_ROOM,
      null
    );
  });

  it('nao mexe na sala aberta quando a marcada e outra', async () => {
    InternalChatAPI.markRoomUnread.mockResolvedValue({ data: { unread: 1 } });
    const commit = vi.fn();

    await actions.markRoomUnread({ commit, state: { activeRoomId: 9 } }, 5);

    expect(commit).not.toHaveBeenCalledWith(
      types.SET_INTERNAL_CHAT_ACTIVE_ROOM,
      null
    );
  });
});
