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
    it('so avisa quando o cliente escreveu por ultimo: depois que respondi, nao', async () => {
      const ultima = (message_type, extra = {}) => ({
        last_non_activity_message: { message_type, ...extra },
      });
      ConversationAPI.get.mockResolvedValue({
        data: {
          data: {
            payload: [
              // o cliente escreveu e eu nao respondi
              { id: 1, unread_count: 1, ...ultima(0) },
              // o cliente escreveu, eu respondi (o servidor ainda diz 1 nao lida)
              { id: 2, unread_count: 1, ...ultima(1) },
              // respondi com um modelo
              { id: 3, unread_count: 2, ...ultima(3) },
              // nota privada depois da mensagem do cliente: continua esperando
              { id: 4, unread_count: 1, ...ultima(1, { private: true }) },
              // sem ultima mensagem conhecida: confia no servidor
              { id: 5, unread_count: 1 },
            ],
          },
        },
      });
      const commit = vi.fn();

      await actions.fetch({ commit });

      expect(commit).toHaveBeenCalledWith('SET_CONVERSATION_IDS', [1, 4, 5]);
    });

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

      expect(commit).not.toHaveBeenCalledWith(
        'ADD_CONVERSATION_ID',
        expect.anything()
      );
    });

    it('uma resposta da equipe apaga o aviso: o cliente ja foi respondido', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ message_type: 1 })
      );

      expect(commit).toHaveBeenCalledWith('REMOVE_CONVERSATION_ID', 436);
    });

    it('uma resposta com modelo tambem apaga o aviso', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ message_type: 3 })
      );

      expect(commit).toHaveBeenCalledWith('REMOVE_CONVERSATION_ID', 436);
    });

    it('uma nota privada nao conta como resposta', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ message_type: 1, private: true })
      );

      expect(commit).not.toHaveBeenCalled();
    });

    it('mensagem de atividade nao acende nem apaga', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        mensagem({ message_type: 2 })
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

  describe('o aviso concorda com o cartao da lista (conversa que eu ja li)', () => {
    const conversa = (extra = {}) => ({
      id: 437,
      unread_count: 1,
      agent_last_seen_at: 0,
      assignee_last_seen_at: 0,
      last_non_activity_message: { message_type: 0, created_at: 1000 },
      ...extra,
    });
    const buscar = async (chats, state) => {
      ConversationAPI.get.mockResolvedValue({
        data: { data: { payload: chats } },
      });
      const commit = vi.fn();
      await actions.fetch({ commit, state });
      return commit.mock.calls.find(
        ([name]) => name === 'SET_CONVERSATION_IDS'
      )[1];
    };

    it('o cliente escreveu e eu nao vi: acende', async () => {
      expect(await buscar([conversa()], { readAt: {} })).toEqual([437]);
    });

    it('o servidor registrou uma leitura minha depois da mensagem: nao acende', async () => {
      expect(
        await buscar([conversa({ agent_last_seen_at: 1005 })], { readAt: {} })
      ).toEqual([]);
      expect(
        await buscar([conversa({ assignee_last_seen_at: 1005 })], {
          readAt: {},
        })
      ).toEqual([]);
    });

    it('eu li aqui depois da mensagem: a busca nao reacende (mesmo que o servidor demore)', async () => {
      expect(await buscar([conversa()], { readAt: { 437: 1010 } })).toEqual([]);
    });

    it('uma mensagem do cliente MAIS NOVA que a minha leitura volta a acender', async () => {
      const nova = conversa({
        last_non_activity_message: { message_type: 0, created_at: 1020 },
      });

      expect(await buscar([nova], { readAt: { 437: 1010 } })).toEqual([437]);
    });

    it('ler a conversa guarda o instante da leitura', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date(1010 * 1000));
      const commit = vi.fn();

      actions.markRead({ commit, dispatch: vi.fn() }, 437);

      expect(commit).toHaveBeenCalledWith('SET_READ_AT', {
        conversationId: 437,
        at: 1010,
      });
      expect(commit).toHaveBeenCalledWith('REMOVE_CONVERSATION_ID', 437);
      actions.clear({ commit: vi.fn() });
      vi.useRealTimers();
    });

    it('mensagem nova do cliente esquece a leitura de antes', () => {
      const commit = vi.fn();

      actions.applyMessage(
        { commit, rootGetters },
        {
          message_type: 0,
          conversation_id: 437,
          conversation: { assignee_id: ME, unread_count: 1 },
        }
      );

      expect(commit).toHaveBeenCalledWith('FORGET_READ', 437);
      expect(commit).toHaveBeenCalledWith('ADD_CONVERSATION_ID', 437);
    });

    it('as mutacoes guardam, esquecem e limpam as leituras', () => {
      const state = { readAt: {} };

      mutations.SET_READ_AT(state, { conversationId: 437, at: 1010 });
      mutations.SET_READ_AT(state, { conversationId: 8, at: 5 });
      expect(state.readAt).toEqual({ 437: 1010, 8: 5 });

      mutations.FORGET_READ(state, 437);
      expect(state.readAt).toEqual({ 8: 5 });

      mutations.CLEAR_READ(state);
      expect(state.readAt).toEqual({});
    });
  });

  describe('markRead e scheduleRefresh', () => {
    beforeEach(() => {
      vi.useFakeTimers();
      ConversationAPI.get.mockReset();
    });

    afterEach(() => {
      actions.clear({ commit: vi.fn() }); // zera a busca agendada de um teste para o outro
      vi.useRealTimers();
    });

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

    it('eventos continuos nao adiam a busca para sempre', () => {
      const dispatch = vi.fn();

      actions.scheduleRefresh({ dispatch });
      vi.advanceTimersByTime(1000);
      actions.scheduleRefresh({ dispatch }); // outro evento antes de buscar
      vi.advanceTimersByTime(600);

      expect(dispatch).toHaveBeenCalledTimes(1);
    });

    it('depois de buscar, um evento novo agenda outra busca', () => {
      const dispatch = vi.fn();
      actions.scheduleRefresh({ dispatch });
      vi.advanceTimersByTime(2000);

      actions.scheduleRefresh({ dispatch });
      vi.advanceTimersByTime(2000);

      expect(dispatch).toHaveBeenCalledTimes(2);
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
