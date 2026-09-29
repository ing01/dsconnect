import { actions, mutations } from '../../internalChat';
import types from '../../../mutation-types';
import InternalChatAPI from 'dashboard/api/internalChat';

// Apagar mensagem no Chat Interno.
//
// Sai da tela de quem apagou na hora e das outras pelo tempo real - a remocao
// local nao espera o eco do proprio navegador, que pode nem chegar se a pessoa
// trocar de tela.
vi.mock('dashboard/api/internalChat', () => ({
  default: { deleteMessage: vi.fn() },
}));

const estado = (extra = {}) => ({
  rooms: [
    {
      id: 5,
      messages: [
        { id: 1, body: 'primeira' },
        { id: 2, body: 'segunda' },
      ],
      lastMessage: { id: 2, body: 'segunda' },
      ...extra,
    },
  ],
});

describe('apagar mensagem', () => {
  it('asks the server and takes the message off the screen', async () => {
    InternalChatAPI.deleteMessage.mockResolvedValue({});
    const commit = vi.fn();

    await actions.deleteMessage({ commit }, { roomId: 5, messageId: 2 });

    expect(InternalChatAPI.deleteMessage).toHaveBeenCalledWith(5, 2);
    expect(commit).toHaveBeenCalledWith(types.REMOVE_INTERNAL_CHAT_MESSAGE, {
      roomId: 5,
      messageId: 2,
    });
  });

  // Recusa do servidor - apagar mensagem alheia, por exemplo - nao pode tirar a
  // mensagem da tela: ela continua existindo.
  it('leaves the message on screen when the server refuses', async () => {
    InternalChatAPI.deleteMessage.mockImplementation(() =>
      Promise.reject(new Error('proibido'))
    );
    const commit = vi.fn();

    let erro = null;
    try {
      await actions.deleteMessage({ commit }, { roomId: 5, messageId: 2 });
    } catch (e) {
      erro = e;
    }

    expect(erro?.message).toBe('proibido');
    expect(commit).not.toHaveBeenCalled();
  });

  it('removes it from the list when the event arrives from someone else', () => {
    const commit = vi.fn();

    actions.applyRealtimeDeletion({ commit }, { channelId: 5, messageId: 1 });

    expect(commit).toHaveBeenCalledWith(types.REMOVE_INTERNAL_CHAT_MESSAGE, {
      roomId: 5,
      messageId: 1,
    });
  });

  describe('a mutacao', () => {
    it('drops only the message it was told to', () => {
      const chatState = estado();

      mutations[types.REMOVE_INTERNAL_CHAT_MESSAGE](chatState, {
        roomId: 5,
        messageId: 1,
      });

      expect(chatState.rooms[0].messages.map(item => item.id)).toEqual([2]);
    });

    // A previa da barra lateral apontava para a mensagem apagada: sem limpar, a
    // lista continuaria mostrando um texto que ja nao existe.
    it('clears the sidebar preview when it pointed at that message', () => {
      const chatState = estado();

      mutations[types.REMOVE_INTERNAL_CHAT_MESSAGE](chatState, {
        roomId: 5,
        messageId: 2,
      });

      expect(chatState.rooms[0].lastMessage).toBeNull();
    });

    it('keeps the preview when another message was removed', () => {
      const chatState = estado();

      mutations[types.REMOVE_INTERNAL_CHAT_MESSAGE](chatState, {
        roomId: 5,
        messageId: 1,
      });

      expect(chatState.rooms[0].lastMessage.id).toBe(2);
    });

    it('survives an event for a room this browser does not know', () => {
      const chatState = estado();

      expect(() =>
        mutations[types.REMOVE_INTERNAL_CHAT_MESSAGE](chatState, {
          roomId: 99,
          messageId: 1,
        })
      ).not.toThrow();
    });
  });
});
