import { actions, getters, mutations } from '../../unreadAssigned';
import ConversationAPI from 'dashboard/api/conversations';

// O aviso de "mensagem nao lida em conversa atribuida a mim": so guarda os numeros
// das conversas, e acende/apaga conforme os eventos do tempo real e a busca.
vi.mock('dashboard/api/conversations', () => ({
  default: { get: vi.fn() },
}));

const ME = 7;
const rootGetters = { getCurrentUserID: ME };

const mensagem = (extra = {}) => ({
  message_type: 0, // do cliente
  conversation_id: 436,
  conversation: { assignee_id: ME, unread_count: 2 },
  ...extra,
});

describe('unreadAssigned', () => {
  describe('getters e mutations', () => {
    it('so ha aviso quando existe alguma conversa na lista', () => {
      expect(getters.hasUnread({ conversationIds: [] })).toBe(false);
      expect(getters.hasUnread({ conversationIds: [436] })).toBe(true);
    });

    it('nao repete a mesma conversa', () => {
      const state = { conversationIds: [] };

      mutations.ADD_CONVERSATION_ID(state, 436);
      mutations.ADD_CONVERSATION_ID(state, 436);
      mutations.SET_CONVERSATION_IDS(state, [1, 1, 2]);

      expect(state.conversationIds).toEqual([1, 2]);
    });

    it('remover uma conversa deixa as outras', () => {
      const state = { conversationIds: [1, 2] };

      mutations.REMOVE_CONVERSATION_ID(state, 1);

      expect(state.conversationIds).toEqual([2]);
    });
  });

  describe('fetch', () => {
    it('busca so as MINHAS conversas ABERTAS e guarda as que tem nao lida', async () => {
      ConversationAPI.get.mockResolvedValue({
        data: {
          data: {
            payload: [
              { id: 1, unread_count: 3 },
              { id: 2, unread_count: 0 },
              { id: 3, unread_count: 1 },
            ],
          },
        },
      });
      const commit = vi.fn();

      await actions.fetch({ commit });

      expect(ConversationAPI.get).toHaveBeenCalledWith({
        assigneeType: 'me',
        status: 'open',
        page: 1,
      });
      expect(commit).toHaveBeenCalledWith('SET_CONVERSATION_IDS', [1, 3]);
    });

    it('com erro de rede, mantem o que ja se sabia', async () => {
      ConversationAPI.get.mockRejectedValue(new Error('offline'));
      const commit = vi.fn();

      await actions.fetch({ commit });

      expect(commit).not.toHaveBeenCalled();
    });
  });

  describe('applyMessage (tempo real)', () => {
    it('mensagem do cliente numa conversa minha acende o aviso', () => {
      const commit = vi.fn();

      actions.applyMessage({ commit, rootGetters }, mensagem());

      expect(commit).toHaveBeenCalledWith('ADD_CONVERSATION_ID', 436);
    });

    it('conversa de outro agente nao acende', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ conversation: { assignee_id: 99, unread_count: 2 } })
      );

      expect(commit).not.toHaveBeenCalled();
    });

    it('conversa sem ninguem atribuido nao acende', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ conversation: { assignee_id: null, unread_count: 2 } })
      );

      expect(commit).not.toHaveBeenCalled();
    });

    it('mensagem enviada por agente (saida) nao acende', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ message_type: 1 })
      );

      expect(commit).not.toHaveBeenCalled();
    });

    it('sem mensagem nao lida (ja lida) nao acende', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ conversation: { assignee_id: ME, unread_count: 0 } })
      );

      expect(commit).not.toHaveBeenCalled();
    });
  });

  describe('markRead e scheduleRefresh', () => {
    beforeEach(() => {
      vi.useFakeTimers();
      ConversationAPI.get.mockReset();
    });

    afterEach(() => vi.useRealTimers());

    it('ler a conversa apaga o aviso dela na hora e confirma depois', () => {
      const commit = vi.fn();
      const dispatch = vi.fn();

      actions.markRead({ commit, dispatch }, 436);

      expect(commit).toHaveBeenCalledWith('REMOVE_CONVERSATION_ID', 436);
      expect(dispatch).toHaveBeenCalledWith('scheduleRefresh');
    });

    it('varios eventos seguidos viram uma busca so', () => {
      const dispatch = vi.fn();

      actions.scheduleRefresh({ dispatch });
      actions.scheduleRefresh({ dispatch });
      actions.scheduleRefresh({ dispatch });
      vi.advanceTimersByTime(2000);

      expect(dispatch).toHaveBeenCalledTimes(1);
      expect(dispatch).toHaveBeenCalledWith('fetch');
    });

    it('limpar zera a lista e cancela a busca agendada', () => {
      const commit = vi.fn();
      const dispatch = vi.fn();
      actions.scheduleRefresh({ dispatch });

      actions.clear({ commit });
      vi.advanceTimersByTime(2000);

      expect(commit).toHaveBeenCalledWith('SET_CONVERSATION_IDS', []);
      expect(dispatch).not.toHaveBeenCalled();
    });
  });
});
