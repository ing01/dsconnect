import types from '../mutation-types';
import ManifestationsAPI from '../../api/manifestations';

/**
 * O SAC do lado da equipe.
 *
 * Duas coisas separadas no estado, de propósito: `records` é a LISTAGEM (já
 * filtrada pelo servidor) e `detail` é a manifestação aberta, com as mensagens e
 * o histórico. Guardar as mensagens dentro do item da lista obrigaria a
 * listagem a carregá-las para todo mundo - e a listagem não as mostra.
 *
 * Os contadores vêm do servidor (`meta`) e não são somados aqui: a tela precisa
 * saber quantas estão pendentes NA CONTA, não quantas couberam no filtro atual.
 */
export const state = {
  records: [],
  detail: null,
  counts: { total: 0, pending: 0, untouched: 0 },
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isUpdating: false,
    isConverting: false,
  },
};

export const getters = {
  getUIFlags: _state => _state.uiFlags,
  getManifestations: _state => _state.records,
  getManifestation: _state => _state.detail,
  getCounts: _state => _state.counts,
};

export const actions = {
  // A listagem com os filtros da tela. Os filtros vão para o servidor em vez de
  // recortarem o que já foi baixado: o acervo cresce, e filtrar no navegador
  // significaria baixar tudo para mostrar pouco.
  fetch: async ({ commit }, filters = {}) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isFetching: true });
    try {
      const { data } = await ManifestationsAPI.list(filters);
      commit(types.SET_MANIFESTATIONS, data.payload);
      commit(types.SET_MANIFESTATION_COUNTS, data.meta);
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isFetching: false });
    }
  },

  show: async ({ commit }, id) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isFetchingItem: true });
    try {
      const { data } = await ManifestationsAPI.show(id);
      commit(types.SET_MANIFESTATION_DETAIL, data);
      return data;
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isFetchingItem: false });
    }
  },

  // Status e responsável. A resposta do servidor substitui o detalhe inteiro -
  // ela já traz o histórico com a movimentação recém-registrada, e remendar o
  // estado aqui significaria manter uma segunda versão dessa regra.
  update: async ({ commit }, { id, ...atributos }) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await ManifestationsAPI.update(id, atributos);
      commit(types.SET_MANIFESTATION_DETAIL, data);
      commit(types.UPDATE_MANIFESTATION, data);
      return data;
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isUpdating: false });
    }
  },

  // Responder ao cliente ou anotar para a equipe. Relê o detalhe em vez de
  // acrescentar a mensagem à mão: a mesma razão de `update`.
  reply: async (
    { commit, dispatch },
    { id, body, internal, awaitingCustomer }
  ) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isUpdating: true });
    try {
      await ManifestationsAPI.reply(id, { body, internal, awaitingCustomer });
      return await dispatch('show', id);
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isUpdating: false });
    }
  },

  convert: async ({ commit }, { id, teamId, ticketCategoryId }) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isConverting: true });
    try {
      const { data } = await ManifestationsAPI.convert(id, {
        teamId,
        ticketCategoryId,
      });
      commit(types.SET_MANIFESTATION_DETAIL, data);
      commit(types.UPDATE_MANIFESTATION, data);
      return data;
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isConverting: false });
    }
  },

  convertToSuggestion: async ({ commit }, id) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isConverting: true });
    try {
      const { data } = await ManifestationsAPI.convertToSuggestion(id);
      commit(types.SET_MANIFESTATION_DETAIL, data);
      commit(types.UPDATE_MANIFESTATION, data);
      return data;
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isConverting: false });
    }
  },

  create: async ({ commit, dispatch }, atributos) => {
    commit(types.SET_MANIFESTATION_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await ManifestationsAPI.create(atributos);
      await dispatch('fetch');
      return data;
    } finally {
      commit(types.SET_MANIFESTATION_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_MANIFESTATION_UI_FLAG](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },

  [types.SET_MANIFESTATIONS](_state, records) {
    _state.records = records || [];
  },

  [types.SET_MANIFESTATION_COUNTS](_state, counts) {
    _state.counts = { total: 0, pending: 0, untouched: 0, ...(counts || {}) };
  },

  [types.SET_MANIFESTATION_DETAIL](_state, manifestation) {
    _state.detail = manifestation || null;
  },

  // Mantém a LISTAGEM em pé depois de uma alteração feita no detalhe, para que
  // voltar à lista não mostre o status antigo. Mescla em vez de substituir: o
  // corpo do detalhe traz campos que a linha da lista não usa, e substituir
  // apagaria o que a lista já tinha.
  [types.UPDATE_MANIFESTATION](_state, manifestation) {
    const indice = _state.records.findIndex(
      item => item.id === manifestation.id
    );
    if (indice === -1) return;

    _state.records.splice(indice, 1, {
      ..._state.records[indice],
      ...manifestation,
    });
  },
};

export default { namespaced: true, state, getters, actions, mutations };
