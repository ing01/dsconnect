import {
  CHANNELS,
  CURRENT_USER_ID,
  DIRECTS,
  USERS,
} from '../../routes/dashboard/internalChat/helpers/mockData';

/**
 * Estado do protótipo do Chat Interno.
 *
 * Vive no Vuex por um motivo concreto: o contador do menu lateral lê um getter,
 * e a tela precisa do mesmo estado. Nenhuma chamada de API acontece aqui - tudo
 * parte de `mockData` e vive só na sessão do navegador, como combinado para
 * esta etapa.
 *
 * O Chat Interno é deliberadamente separado das Conversations com clientes, dos
 * comentários internos e da comunicação com o cliente dos Tickets. Ele só
 * conhece funcionários, grupos e canais.
 */

const clone = value => JSON.parse(JSON.stringify(value));

export const state = {
  users: clone(USERS),
  channels: clone(CHANNELS),
  directs: clone(DIRECTS),
  currentUserId: CURRENT_USER_ID,
};

export const getters = {
  getUsers: _state => _state.users,
  getChannels: _state => _state.channels,
  getDirects: _state => _state.directs,
  getCurrentUserId: _state => _state.currentUserId,

  getUserById: _state => id => _state.users.find(user => user.id === id),

  // O que o badge do menu mostra: tudo que ainda não foi lido, privado ou não.
  getUnreadCount: _state =>
    [..._state.directs, ..._state.channels].reduce(
      (total, room) => total + room.unread,
      0
    ),

  // Uma sala é um canal ou uma conversa privada; a tela trata as duas pelo
  // mesmo contrato para não duplicar a lista de mensagens.
  getRoomById: _state => id =>
    _state.channels.find(channel => channel.id === id) ||
    _state.directs.find(direct => direct.id === id),
};

export const actions = {
  // Abrir a sala zera o não lido, como em qualquer mensageiro.
  markRead: ({ commit }, roomId) => commit('MARK_READ', roomId),

  sendMessage: (
    { commit, state: _state },
    { roomId, body, attachment, replyTo }
  ) => {
    const message = {
      id: `m-${Date.now()}`,
      userId: _state.currentUserId,
      body,
      createdAt: Date.now(),
      reactions: [],
      ...(attachment ? { attachment } : {}),
      ...(replyTo ? { replyTo } : {}),
    };
    commit('ADD_MESSAGE', { roomId, message });
    return message;
  },

  toggleReaction: ({ commit }, payload) => commit('TOGGLE_REACTION', payload),

  createChannel: ({ commit }, { name, description, memberIds }) => {
    const channel = {
      id: `c-${Date.now()}`,
      name,
      description,
      memberIds,
      unread: 0,
      messages: [],
    };
    commit('ADD_CHANNEL', channel);
    return channel;
  },

  // Abrir conversa com alguém: reaproveita a que já existir, em vez de criar
  // uma segunda linha para a mesma pessoa.
  openDirect: ({ commit, state: _state }, userId) => {
    const existing = _state.directs.find(direct => direct.userId === userId);
    if (existing) return existing;

    const direct = { id: `d-${Date.now()}`, userId, unread: 0, messages: [] };
    commit('ADD_DIRECT', direct);
    return direct;
  },
};

const findRoom = (_state, roomId) =>
  _state.channels.find(channel => channel.id === roomId) ||
  _state.directs.find(direct => direct.id === roomId);

export const mutations = {
  MARK_READ(_state, roomId) {
    const room = findRoom(_state, roomId);
    if (room) room.unread = 0;
  },

  ADD_MESSAGE(_state, { roomId, message }) {
    const room = findRoom(_state, roomId);
    if (room) room.messages.push(message);
  },

  TOGGLE_REACTION(_state, { roomId, messageId, emoji }) {
    const room = findRoom(_state, roomId);
    const message = room?.messages.find(item => item.id === messageId);
    if (!message) return;

    const existing = message.reactions.find(item => item.emoji === emoji);
    if (!existing) {
      message.reactions.push({ emoji, userIds: [_state.currentUserId] });
      return;
    }

    const index = existing.userIds.indexOf(_state.currentUserId);
    if (index === -1) existing.userIds.push(_state.currentUserId);
    else existing.userIds.splice(index, 1);

    // Uma reação sem ninguém não é uma reação.
    if (!existing.userIds.length) {
      message.reactions = message.reactions.filter(
        item => item.emoji !== emoji
      );
    }
  },

  ADD_CHANNEL(_state, channel) {
    _state.channels.push(channel);
  },

  ADD_DIRECT(_state, direct) {
    _state.directs.push(direct);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
