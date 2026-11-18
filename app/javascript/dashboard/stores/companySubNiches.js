import camelcaseKeys from 'camelcase-keys';
import { defineStore } from 'pinia';
import CompanySubNicheAPI from 'dashboard/api/companySubNiches';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useCompanySubNichesStore = defineStore('companySubNiches', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isCreating: false },
  }),

  getters: {
    getSubNiches: state => state.records,
  },

  actions: {
    async get() {
      this.uiFlags.isFetching = true;
      try {
        const {
          data: { payload },
        } = await CompanySubNicheAPI.get();
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
        } = await CompanySubNicheAPI.create({ name });
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
