import { buildDemoRooms } from '../../routes/dashboard/internalChat/helpers/mockData';

/**
 * Estado do protótipo do Chat Interno.
 *
 * As pessoas são reais: o diretório vem dos agentes da conta, que é com quem se
 * espera conversar. O que ainda é simulado são as conversas e as mensagens, que
 * vivem só na sessão do navegador - não há tabela nem endpoint nesta etapa.
 *
 * Vive no Vuex por um motivo concreto: o contador do menu lateral lê um getter,
 * e a tela precisa do mesmo estado.
 *
 * O Chat Interno é deliberadamente separado das Conversations com clientes, dos
 * comentários internos e da comunicação com o cliente dos Tickets. Ele só
 * conhece funcionários, grupos e canais.
 */

export const state = {
  users: [],
  channels: [],
  directs: [],
  currentUserId: null,
  // As conversas de demonstração são montadas uma vez, quando os agentes
  // chegam; remontar a cada visita apagaria o que foi escrito na sessão.
  isSeeded: false,
};

export const getters = {
  getUsers: _state => _state.users,
  getChannels: _state => _state.channels,
  getDirects: _state => _state.directs,
  getCurrentUserId: _state => _state.currentUserId,
  getIsSeeded: _state => _state.isSeeded,

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

export const actions = {
  /**
   * Monta o diretório a partir dos agentes reais da conta e semeia as conversas
   * de demonstração sobre eles.
   */
  initialise: ({ commit, state: _state, rootGetters }) => {
    const currentUser = rootGetters.getCurrentUser || {};
    const agents = rootGetters['agents/getVerifiedAgents'] || [];

    // O usuário logado vem primeiro, e entra no diretório mesmo que ainda não
    // conste na lista de agentes carregada.
    const others = agents.filter(agent => agent.id !== currentUser.id);
    const users = [
      ...(currentUser.id
        ? [toDirectoryUser({ ...currentUser, availability_status: 'online' })]
        : []),
      ...others.map(toDirectoryUser),
    ];

    commit('SET_DIRECTORY', { users, currentUserId: currentUser.id || null });

    // Semeia uma única vez: o que foi escrito durante a sessão permanece.
    if (_state.isSeeded || !users.length) return;

    commit('SEED_ROOMS', buildDemoRooms(users, currentUser.id));
  },

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

    const direct = { id: `d-${userId}`, userId, unread: 0, messages: [] };
    commit('ADD_DIRECT', direct);
    return direct;
  },
};

const findRoom = (_state, roomId) =>
  _state.channels.find(channel => channel.id === roomId) ||
  _state.directs.find(direct => direct.id === roomId);

export const mutations = {
  SET_DIRECTORY(_state, { users, currentUserId }) {
    _state.users = users;
    _state.currentUserId = currentUserId;
  },

  SEED_ROOMS(_state, { channels, directs }) {
    _state.channels = channels;
    _state.directs = directs;
    _state.isSeeded = true;
  },

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
