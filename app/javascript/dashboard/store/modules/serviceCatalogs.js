import types from '../mutation-types';
import ServiceCatalogsAPI from '../../api/serviceCatalogs';

// The service catalogue used to classify an attendance: Catalogo > Area > Item.
// The whole tree is held at once because it is small and every consumer - the
// settings screen and the classification dialog - needs all three levels.
export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getCatalogs(_state) {
    return _state.records;
  },
  // Only what an agent may choose from. Records already used by tickets are
  // deactivated rather than deleted, so the pickers filter while the settings
  // screen still lists everything.
  getActiveCatalogs(_state) {
    return _state.records
      .filter(catalog => catalog.active)
      .map(catalog => ({
        ...catalog,
        areas: (catalog.areas || [])
          .filter(area => area.active)
          .map(area => ({
            ...area,
            items: (area.items || []).filter(item => item.active),
          })),
      }));
  },
};

export const actions = {
  fetch: async ({ commit }) => {
    commit(types.SET_SERVICE_CATALOG_UI_FLAG, { isFetching: true });
    try {
      const response = await ServiceCatalogsAPI.get();
      commit(types.SET_SERVICE_CATALOGS, response.data);
      return response.data;
    } finally {
      commit(types.SET_SERVICE_CATALOG_UI_FLAG, { isFetching: false });
    }
  },
  // Every mutation refetches the tree rather than patching it in place: the
  // payload is one small request and the alternative is three levels of local
  // bookkeeping that can drift.
  createCatalog: async ({ dispatch }, data) => {
    await ServiceCatalogsAPI.create({ service_catalog: data });
    return dispatch('fetch');
  },
  updateCatalog: async ({ dispatch }, { id, ...data }) => {
    await ServiceCatalogsAPI.update(id, { service_catalog: data });
    return dispatch('fetch');
  },
  deleteCatalog: async ({ dispatch }, id) => {
    await ServiceCatalogsAPI.delete(id);
    return dispatch('fetch');
  },
  createArea: async ({ dispatch }, { catalogId, ...data }) => {
    await ServiceCatalogsAPI.createArea(catalogId, data);
    return dispatch('fetch');
  },
  updateArea: async ({ dispatch }, { catalogId, areaId, ...data }) => {
    await ServiceCatalogsAPI.updateArea(catalogId, areaId, data);
    return dispatch('fetch');
  },
  deleteArea: async ({ dispatch }, { catalogId, areaId }) => {
    await ServiceCatalogsAPI.deleteArea(catalogId, areaId);
    return dispatch('fetch');
  },
  createItem: async ({ dispatch }, { catalogId, areaId, ...data }) => {
    await ServiceCatalogsAPI.createItem(catalogId, areaId, data);
    return dispatch('fetch');
  },
  updateItem: async ({ dispatch }, { catalogId, areaId, itemId, ...data }) => {
    await ServiceCatalogsAPI.updateItem(catalogId, areaId, itemId, data);
    return dispatch('fetch');
  },
  deleteItem: async ({ dispatch }, { catalogId, areaId, itemId }) => {
    await ServiceCatalogsAPI.deleteItem(catalogId, areaId, itemId);
    return dispatch('fetch');
  },
};

export const mutations = {
  [types.SET_SERVICE_CATALOG_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SERVICE_CATALOGS](_state, records) {
    _state.records = records;
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
