import camelcaseKeys from 'camelcase-keys';
import { defineStore } from 'pinia';
import SystemModuleAPI from 'dashboard/api/systemModules';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useSystemModulesStore = defineStore('systemModules', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isCreating: false },
  }),

  getters: {
    getModules: state => state.records,
  },

  actions: {
    async get() {
      this.uiFlags.isFetching = true;
      try {
        const {
          data: { payload },
        } = await SystemModuleAPI.get();
        this.records = camelcaseKeys(payload || [], { deep: true });
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async create(name) {
      this.uiFlags.isCreating = true;
      try {
        const {
          data: { payload },
        } = await SystemModuleAPI.create({ name });
        const record = camelcaseKeys(payload, { deep: true });
        this.records.push(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isCreating = false;
      }
    },
  },
});
