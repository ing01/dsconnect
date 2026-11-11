import ConversationAPI from '../../api/conversations';

/**
 * Conversas ABERTAS, atribuidas a quem esta logado, em que o CLIENTE escreveu e eu ainda
 * nao respondi (mensagem nao lida e a ultima mensagem da conversa e' do cliente).
 *
 * Alimenta o aviso "!" das abas do topo, do menu lateral e da aba do navegador.
 * Fica a parte da lista de conversas de proposito: aquela so tem o que a tela de
 * Conversas carregou, e o aviso precisa funcionar de qualquer tela.
 *
 * So guarda os numeros (display_id) das conversas: o aviso nao e' um contador.
 */
export const state = {
  conversationIds: [],
  // Conversas que EU li neste navegador, com o instante (segundos). O cartao da lista zera
  // o contador na hora em que a pessoa le; o servidor pode demorar (ou nem contar) a leitura.
  // Para o aviso nao discordar do cartao, uma conversa lida so volta a acender com uma
  // mensagem do cliente MAIS NOVA que essa leitura.
  readAt: {},
};

export const getters = {
  hasUnread: _state => _state.conversationIds.length > 0,
  getConversationIds: _state => _state.conversationIds,
};

// Varios eventos seguidos (ler, atribuir, mudar status, "nao lidas mudou") viram uma
// busca so, no maximo uma a cada 1,5 s. O relogio NAO reinicia a cada evento: numa conta
// movimentada os eventos nunca param, e reiniciar adiaria a busca para sempre.
const REFRESH_DELAY_MS = 1500;
let refreshTimer = null;

// Tipos de mensagem do servidor: 0 = do cliente, 1 = da equipe, 2 = atividade, 3 = modelo.
const INCOMING = 0;
const OUTGOING = 1;
const TEMPLATE = 3;

// O cliente esta esperando a minha resposta? O servidor so conta a mensagem como lida quando
// a conversa e' aberta - responder nao conta -, entao `unread_count` sozinho continuaria
// acusando "nao lida" depois de eu responder. A ultima mensagem da conversa diz melhor:
// se foi o cliente quem escreveu por ultimo, ele espera; se foi a equipe, ja respondemos.
// Nota privada nao e' resposta: nao encerra a espera.
const isWaitingForMe = (chat, readAt = {}) => {
  if (!(Number(chat?.unread_count) > 0)) return false;

  const last = chat.last_non_activity_message;
  if (!last) return true;
  if (!(Number(last.message_type) === INCOMING || last.private === true)) {
    return false;
  }

  // Ja vi depois que ela chegou? Vale o que o servidor registrou e o que li aqui.
  const arrivedAt = Number(last.created_at);
  const seenAt = Math.max(
    Number(chat.agent_last_seen_at) || 0,
    Number(chat.assignee_last_seen_at) || 0,
    Number(readAt[chat.id]) || 0
  );
  return !(seenAt && arrivedAt && arrivedAt <= seenAt);
};

export const actions = {
  // A fonte da verdade: a lista do servidor, que ja traz `unread_count` de cada
  // conversa. Erro de rede nao derruba nada - o aviso so fica como estava.
  fetch: async ({ commit, state: _state = { readAt: {} } }) => {
    try {
      const response = await ConversationAPI.get({
        assigneeType: 'me',
        status: 'open',
        page: 1,
      });
      const chats = response?.data?.data?.payload || [];
      commit(
        'SET_CONVERSATION_IDS',
        chats
          .filter(chat => isWaitingForMe(chat, _state.readAt))
          .map(chat => chat.id)
      );
    } catch (error) {
      // sem rede ou sem permissao: mantem o que ja se sabia
    }
  },

  // Eventos em que nao da' para saber o resultado de cabeca: refaz a busca, mas
  // agrupando. Quem le a conversa tira o aviso na hora (`markRead`) e o resto
  // espera a confirmacao do servidor.
  scheduleRefresh: ({ dispatch }) => {
    if (refreshTimer) return;
    refreshTimer = setTimeout(() => {
      refreshTimer = null;
      dispatch('fetch');
    }, REFRESH_DELAY_MS);
  },

  // Chegou mensagem numa conversa, sem pedir nada ao servidor (o evento ja diz de quem e'
  // a conversa e quantas nao lidas ha):
  // - do CLIENTE numa conversa MINHA: acende o aviso;
  // - da EQUIPE (uma resposta, nao nota privada): o cliente ja foi respondido, apaga.
  // Atividade e conversa de outra pessoa nao acendem.
  applyMessage: ({ commit, rootGetters }, data) => {
    const conversation = data?.conversation;
    if (!conversation) return;

    const type = Number(data.message_type);
    const isReply = (type === OUTGOING || type === TEMPLATE) && !data.private;
    if (isReply) {
      commit('REMOVE_CONVERSATION_ID', data.conversation_id);
      return;
    }

    if (type !== INCOMING) return;
    if (conversation.assignee_id !== rootGetters.getCurrentUserID) return;
    if (!(Number(conversation.unread_count) > 0)) return;

    // Mensagem nova do cliente: vale mais que a leitura de antes.
    commit('FORGET_READ', data.conversation_id);
    commit('ADD_CONVERSATION_ID', data.conversation_id);
  },

  // Eu abri/li a conversa neste navegador: o aviso dela some na hora e o servidor
  // confirma logo depois. (Ler em OUTRO aparelho chega por `conversation.unread_count_changed`.)
  markRead: ({ commit, dispatch }, conversationId) => {
    commit('SET_READ_AT', {
      conversationId,
      at: Math.floor(Date.now() / 1000),
    });
    commit('REMOVE_CONVERSATION_ID', conversationId);
    dispatch('scheduleRefresh');
  },

  clear: ({ commit }) => {
    clearTimeout(refreshTimer);
    refreshTimer = null;
    commit('SET_CONVERSATION_IDS', []);
    commit('CLEAR_READ');
  },
};

export const mutations = {
  SET_CONVERSATION_IDS(_state, ids) {
    _state.conversationIds = [...new Set(ids)];
  },
  ADD_CONVERSATION_ID(_state, id) {
    if (id === undefined || id === null) return;
    if (!_state.conversationIds.includes(id)) _state.conversationIds.push(id);
  },
  SET_READ_AT(_state, { conversationId, at }) {
    if (conversationId === undefined || conversationId === null) return;
    _state.readAt = { ..._state.readAt, [conversationId]: at };
  },
  FORGET_READ(_state, conversationId) {
    if (!(conversationId in _state.readAt)) return;
    const rest = { ..._state.readAt };
    delete rest[conversationId];
    _state.readAt = rest;
  },
  CLEAR_READ(_state) {
    _state.readAt = {};
  },
  REMOVE_CONVERSATION_ID(_state, id) {
    _state.conversationIds = _state.conversationIds.filter(item => item !== id);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
