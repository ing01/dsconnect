import InternalChatAPI from '../../api/internalChat';
import types from '../mutation-types';

/**
 * Estado do Chat Interno.
 *
 * As salas, as mensagens e o que cada um leu vivem no servidor - recarregar a
 * página não apaga nada, e o que uma pessoa escreve chega às outras. O
 * navegador só guarda o que já foi buscado.
 *
 * Vive no Vuex porque o contador do menu lateral lê um getter e a tela precisa
 * do mesmo estado.
 *
 * Deliberadamente separado das Conversations com clientes, dos comentários
 * internos e da comunicação com o cliente dos Tickets: aqui só existe
 * funcionário, grupo e canal.
 */

export const state = {
  users: [],
  // As salas, na forma que a tela usa. Canal e conversa privada são o mesmo
  // registro no servidor e só diferem no `kind`.
  rooms: [],
  currentUserId: null,
  // Qual sala está aberta. O store precisa saber para decidir se uma mensagem
  // que chega pelo tempo real conta como não lida.
  activeRoomId: null,
  // Buscadas a parte, por sala, porque nem sempre estao dentro da janela de
  // mensagens ja carregada (fixar uma antiga nao a traz de volta pro historico
  // recente).
  pinnedMessages: {},
  uiFlags: {
    isFetchingRooms: false,
    isFetchingMessages: false,
    isSending: false,
  },
};

export const getters = {
  getUsers: _state => _state.users,
  getChannels: _state => _state.rooms.filter(room => room.kind === 'channel'),
  getDirects: _state => _state.rooms.filter(room => room.kind === 'direct'),
  getCurrentUserId: _state => _state.currentUserId,
  getActiveRoomId: _state => _state.activeRoomId,
  getUIFlags: _state => _state.uiFlags,

  getUserById: _state => id => _state.users.find(user => user.id === id),

  // O que o badge do menu mostra. Vem do servidor, contado por pessoa, então é
  // o mesmo número em qualquer aparelho.
  getUnreadCount: _state =>
    _state.rooms.reduce((total, room) => total + (room.unread || 0), 0),

  getRoomById: _state => id => _state.rooms.find(room => room.id === id),

  getPinnedMessages: _state => roomId => _state.pinnedMessages[roomId] || [],
};

/**
 * Converte um agente da conta no formato que a tela do Chat usa.
 * @param {object} agent registro do store `agents`
 * @returns {object} pessoa do diretório
 */
const toDirectoryUser = agent => ({
  id: agent.id,
  name: agent.name,
  role: agent.role,
  // A disponibilidade já existe no produto; o Chat só a apresenta.
  status: agent.availability_status || 'offline',
  thumbnail: agent.thumbnail,
});

/**
 * Uma sala vinda da API, com espaço para as mensagens que ainda não foram
 * buscadas.
 * @param {object} room sala serializada pelo backend
 * @param {Array} previousMessages mensagens já carregadas, se houver
 * @returns {object} sala pronta para a tela
 */
const toRoom = (room, previousMessages = []) => ({
  ...room,
  messages: previousMessages,
  // As mensagens são buscadas ao abrir a sala, não junto da lista.
  isLoaded: previousMessages.length > 0,
});

export const actions = {
  // O diretório são os agentes da conta - é com eles que se conversa.
  setDirectory: ({ commit, rootGetters }) => {
    const currentUser = rootGetters.getCurrentUser || {};
    const agents = rootGetters['agents/getVerifiedAgents'] || [];

    const others = agents.filter(agent => agent.id !== currentUser.id);
    const users = [
      ...(currentUser.id
        ? [toDirectoryUser({ ...currentUser, availability_status: 'online' })]
        : []),
      ...others.map(toDirectoryUser),
    ];

    commit(types.SET_INTERNAL_CHAT_DIRECTORY, {
      users,
      currentUserId: currentUser.id || null,
    });
  },

  fetchRooms: async ({ commit }) => {
    commit(types.SET_INTERNAL_CHAT_UI_FLAG, { isFetchingRooms: true });
    try {
      const response = await InternalChatAPI.get();
      commit(types.SET_INTERNAL_CHAT_ROOMS, response.data.payload);
    } finally {
      commit(types.SET_INTERNAL_CHAT_UI_FLAG, { isFetchingRooms: false });
    }
  },

  fetchMessages: async ({ commit }, roomId) => {
    commit(types.SET_INTERNAL_CHAT_UI_FLAG, { isFetchingMessages: true });
    try {
      const response = await InternalChatAPI.getMessages(roomId);
      commit(types.SET_INTERNAL_CHAT_MESSAGES, {
        roomId,
        messages: response.data.payload,
      });
    } finally {
      commit(types.SET_INTERNAL_CHAT_UI_FLAG, { isFetchingMessages: false });
    }
  },

  setActiveRoom: ({ commit }, roomId) =>
    commit(types.SET_INTERNAL_CHAT_ACTIVE_ROOM, roomId),

  /**
   * Uma mensagem chegou pelo ActionCable.
   *
   * Serve para mensagem nova e para mensagem alterada: as duas trazem o
   * registro completo, então o store insere ou substitui pelo id.
   *
   * Só entra na sala se ela já tiver sido carregada - senão a conversa
   * apareceria com um único recado solto, sem o histórico que vem antes dele.
   */
  applyRealtimeMessage: (
    { commit, state: _state, dispatch },
    { channelId, message }
  ) => {
    const room = _state.rooms.find(item => item.id === channelId);
    if (!room) return;

    const isKnown = room.messages.some(item => item.id === message.id);
    if (isKnown) {
      commit(types.UPDATE_INTERNAL_CHAT_MESSAGE, {
        roomId: channelId,
        message,
      });
      return;
    }

    if (room.isLoaded) {
      commit(types.ADD_INTERNAL_CHAT_MESSAGE, { roomId: channelId, message });
    }

    // A própria mensagem da pessoa nunca conta como não lida - ela pode chegar
    // aqui vinda de outra aba dela mesma.
    if (message.userId === _state.currentUserId) return;

    // Com a sala aberta, ler é imediato; fechada, o contador sobe.
    if (channelId === _state.activeRoomId) {
      dispatch('markRead', channelId);
      return;
    }

    commit(types.SET_INTERNAL_CHAT_UNREAD, {
      roomId: channelId,
      unread: (room.unread || 0) + 1,
    });
  },

  // Abrir a sala zera o não lido no servidor, para todos os aparelhos da
  // pessoa - e não só nesta aba.
  markRead: async ({ commit }, roomId) => {
    commit(types.SET_INTERNAL_CHAT_UNREAD, { roomId, unread: 0 });
    await InternalChatAPI.markRead(roomId);
  },

  sendMessage: async ({ commit }, { roomId, body, replyTo, attachments }) => {
    commit(types.SET_INTERNAL_CHAT_UI_FLAG, { isSending: true });
    try {
      const response = await InternalChatAPI.sendMessage(roomId, {
        content: body,
        replyToId: replyTo,
        attachments,
      });
      commit(types.ADD_INTERNAL_CHAT_MESSAGE, {
        roomId,
        message: response.data,
      });
      return response.data;
    } finally {
      commit(types.SET_INTERNAL_CHAT_UI_FLAG, { isSending: false });
    }
  },

  toggleReaction: async ({ commit }, { roomId, messageId, emoji }) => {
    const response = await InternalChatAPI.toggleReaction(
      roomId,
      messageId,
      emoji
    );
    commit(types.UPDATE_INTERNAL_CHAT_MESSAGE, {
      roomId,
      message: response.data,
    });
  },

  // Apagar sai da tela de quem apagou na hora; nas outras, pelo tempo real
  // (`applyRealtimeDeletion`). A remocao local nao espera o eco do proprio
  // navegador, que pode nem chegar se a pessoa trocar de tela.
  deleteMessage: async ({ commit }, { roomId, messageId }) => {
    await InternalChatAPI.deleteMessage(roomId, messageId);
    commit(types.REMOVE_INTERNAL_CHAT_MESSAGE, { roomId, messageId });
  },

  applyRealtimeDeletion: ({ commit }, { channelId, messageId }) =>
    commit(types.REMOVE_INTERNAL_CHAT_MESSAGE, {
      roomId: channelId,
      messageId,
    }),

  createChannel: async (
    { commit },
    {
      name,
      description,
      visibility,
      memberIds,
      pinned,
      postingPolicy,
      moderatorIds,
    }
  ) => {
    const response = await InternalChatAPI.createChannel({
      name,
      description,
      visibility,
      memberIds,
      pinned,
      postingPolicy,
      moderatorIds,
    });
    commit(types.ADD_INTERNAL_CHAT_ROOM, response.data);
    return response.data;
  },

  updateChannel: async ({ commit }, { roomId, ...fields }) => {
    const response = await InternalChatAPI.updateChannel(roomId, fields);
    commit(types.ADD_INTERNAL_CHAT_ROOM, response.data);
    return response.data;
  },

  // Pedir a conversa com alguém duas vezes devolve a mesma sala: o servidor
  // reaproveita a que existir.
  openDirect: async ({ commit }, userId) => {
    const response = await InternalChatAPI.openDirect(userId);
    commit(types.ADD_INTERNAL_CHAT_ROOM, response.data);
    return response.data;
  },

  deleteChannel: async ({ commit }, roomId) => {
    await InternalChatAPI.deleteChannel(roomId);
    commit(types.REMOVE_INTERNAL_CHAT_ROOM, roomId);
  },

  addMember: async ({ commit }, { roomId, userId }) => {
    const response = await InternalChatAPI.addMember(roomId, userId);
    commit(types.ADD_INTERNAL_CHAT_ROOM, response.data);
    return response.data;
  },

  removeMember: async ({ commit }, { roomId, userId }) => {
    const response = await InternalChatAPI.removeMember(roomId, userId);
    commit(types.ADD_INTERNAL_CHAT_ROOM, response.data);
    return response.data;
  },

  fetchPinnedMessages: async ({ commit }, roomId) => {
    const response = await InternalChatAPI.getPinnedMessages(roomId);
    commit(types.SET_INTERNAL_CHAT_PINNED_MESSAGES, {
      roomId,
      messages: response.data.payload,
    });
  },

  togglePin: async ({ commit, dispatch }, { roomId, messageId }) => {
    const response = await InternalChatAPI.togglePin(roomId, messageId);
    commit(types.UPDATE_INTERNAL_CHAT_MESSAGE, {
      roomId,
      message: response.data,
    });
    dispatch('fetchPinnedMessages', roomId);
  },
};

const findRoom = (_state, roomId) =>
  _state.rooms.find(room => room.id === roomId);

export const mutations = {
  [types.SET_INTERNAL_CHAT_DIRECTORY](_state, { users, currentUserId }) {
    _state.users = users;
    _state.currentUserId = currentUserId;
  },

  [types.SET_INTERNAL_CHAT_ACTIVE_ROOM](_state, roomId) {
    _state.activeRoomId = roomId;
  },

  [types.SET_INTERNAL_CHAT_UI_FLAG](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },

  // Preserva as mensagens já carregadas: recarregar a lista de salas não pode
  // esvaziar a conversa aberta.
  [types.SET_INTERNAL_CHAT_ROOMS](_state, rooms) {
    _state.rooms = rooms.map(room => {
      const existing = findRoom(_state, room.id);
      return toRoom(room, existing?.messages || []);
    });
  },

  [types.ADD_INTERNAL_CHAT_ROOM](_state, room) {
    const existing = findRoom(_state, room.id);
    if (existing) {
      Object.assign(existing, room);
      return;
    }
    _state.rooms.push(toRoom(room));
  },

  [types.SET_INTERNAL_CHAT_MESSAGES](_state, { roomId, messages }) {
    const room = findRoom(_state, roomId);
    if (!room) return;

    room.messages = messages;
    room.isLoaded = true;
  },

  [types.ADD_INTERNAL_CHAT_MESSAGE](_state, { roomId, message }) {
    const room = findRoom(_state, roomId);
    if (!room) return;
    // O servidor pode devolver algo que já chegou por outro caminho.
    if (room.messages.some(item => item.id === message.id)) return;

    room.messages.push(message);
  },

  [types.UPDATE_INTERNAL_CHAT_MESSAGE](_state, { roomId, message }) {
    const room = findRoom(_state, roomId);
    const index = room?.messages.findIndex(item => item.id === message.id);
    if (index === undefined || index === -1) return;

    room.messages.splice(index, 1, message);
  },

  [types.REMOVE_INTERNAL_CHAT_MESSAGE](_state, { roomId, messageId }) {
    const room = findRoom(_state, roomId);
    if (!room) return;

    room.messages = room.messages.filter(item => item.id !== messageId);
    // A previa da barra lateral aponta para a mensagem apagada: sem limpar, a
    // lista continuaria mostrando um texto que ja nao existe. O proximo
    // carregamento da lista traz a previa correta.
    if (room.lastMessage?.id === messageId) room.lastMessage = null;
  },

  [types.SET_INTERNAL_CHAT_UNREAD](_state, { roomId, unread }) {
    const room = findRoom(_state, roomId);
    if (room) room.unread = unread;
  },

  [types.REMOVE_INTERNAL_CHAT_ROOM](_state, roomId) {
    _state.rooms = _state.rooms.filter(room => room.id !== roomId);
  },

  [types.SET_INTERNAL_CHAT_PINNED_MESSAGES](_state, { roomId, messages }) {
    _state.pinnedMessages = { ..._state.pinnedMessages, [roomId]: messages };
  },
};

export default { namespaced: true, state, getters, actions, mutations };
