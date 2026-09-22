import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import { defineStore } from 'pinia';
import ContractAPI from 'dashboard/api/contracts';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const camelizeContract = data => camelcaseKeys(data || {}, { deep: true });

export const useContractsStore = defineStore('contracts', {
  state: () => ({
    records: [],
    meta: { totalCount: 0, page: 1 },
    uiFlags: {
      isFetching: false,
      isSearching: false,
      isCreating: false,
      isUpdating: false,
      isDeleting: false,
    },
  }),

  getters: {
    getContracts: state => state.records,
    getMeta: state => state.meta,
  },

  actions: {
    setMeta(meta) {
      this.meta = {
        totalCount: Number(meta?.total_count || 0),
        page: Number(meta?.page || 1),
      };
    },

    async get(page = 1) {
      this.uiFlags.isFetching = true;
      try {
        const {
          data: { payload, meta },
        } = await ContractAPI.get({ page });
        this.records = payload.map(camelizeContract);
        this.setMeta(meta);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async search(query, page = 1) {
      this.uiFlags.isSearching = true;
      try {
        const {
          data: { payload, meta },
        } = await ContractAPI.search(query, page);
        this.setMeta(meta);
        return payload.map(camelizeContract);
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isSearching = false;
      }
    },

    async create(payload) {
      this.uiFlags.isCreating = true;
      try {
        const {
          data: { payload: created },
        } = await ContractAPI.create(snakecaseKeys(payload, { deep: true }));
        const record = camelizeContract(created);
        this.records = [record, ...this.records];
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
        } = await ContractAPI.update(id, snakecaseKeys(payload, { deep: true }));
        const record = camelizeContract(updated);
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
        await ContractAPI.delete(id);
        this.records = this.records.filter(item => item.id !== id);
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isDeleting = false;
      }
    },
  },
});
