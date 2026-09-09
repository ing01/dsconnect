import camelcaseKeys from 'camelcase-keys';
import { defineStore } from 'pinia';
import CompanyCategoryAPI from 'dashboard/api/companyCategories';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useCompanyCategoriesStore = defineStore('companyCategories', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isCreating: false },
  }),

  getters: {
    getCategories: state => state.records,
  },

  actions: {
    async get() {
      this.uiFlags.isFetching = true;
      try {
        const {
          data: { payload },
        } = await CompanyCategoryAPI.get();
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
        } = await CompanyCategoryAPI.create({ name });
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
