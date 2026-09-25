import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import { defineStore } from 'pinia';
import ProductGroupAPI from 'dashboard/api/productGroups';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useProductGroupsStore = defineStore('productGroups', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isCreating: false, isUpdating: false, isDeleting: false },
  }),

  getters: {
    getProductGroups: state => state.records,
  },

  actions: {
    async get() {
      this.uiFlags.isFetching = true;
      try {
        const {
          data: { payload },
        } = await ProductGroupAPI.get();
        this.records = camelcaseKeys(payload || [], { deep: true });
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async create(payload) {
      this.uiFlags.isCreating = true;
      try {
        const {
          data: { payload: created },
        } = await ProductGroupAPI.create(snakecaseKeys(payload, { deep: true }));
        const record = camelcaseKeys(created, { deep: true });
        this.records.push(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isCreating = false;
      }
    },

    async update(id, payload) {
      this.uiFlags.isUpdating = true;
      try {
        const {
          data: { payload: updated },
        } = await ProductGroupAPI.update(id, snakecaseKeys(payload, { deep: true }));
        const record = camelcaseKeys(updated, { deep: true });
        this.records = this.records.map(item =>
          item.id === record.id ? record : item
        );
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isUpdating = false;
      }
    },

    async delete(id) {
      this.uiFlags.isDeleting = true;
      try {
        await ProductGroupAPI.delete(id);
        this.records = this.records.filter(item => item.id !== id);
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isDeleting = false;
      }
    },
  },
});
