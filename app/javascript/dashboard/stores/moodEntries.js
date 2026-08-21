import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import MoodEntryAPI from 'dashboard/api/moodEntries';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const camelizeMoodEntry = data => camelcaseKeys(data || {}, { deep: true });

export const useMoodEntriesStore = createStore({
  name: 'moodEntries',
  type: 'pinia',
  API: MoodEntryAPI,
  state: () => ({
    todayEntry: null,
    todayChecked: false,
  }),

  actions: () => ({
    async fetchToday() {
      this.setUIFlag({ fetchingItem: true });
      try {
        const {
          data: { payload },
        } = await MoodEntryAPI.today();
        this.todayEntry = payload ? camelizeMoodEntry(payload) : null;
        this.todayChecked = true;
        return this.todayEntry;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingItem: false });
      }
    },

    async create(mood) {
      this.setUIFlag({ creatingItem: true });
      try {
        const {
          data: { payload },
        } = await MoodEntryAPI.create({ mood });
        const moodEntry = camelizeMoodEntry(payload);
        this.todayEntry = moodEntry;
        return moodEntry;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    async fetchAll(filters = {}) {
      this.setUIFlag({ fetchingList: true });
      try {
        const {
          data: { payload },
        } = await MoodEntryAPI.get(snakecaseKeys(filters));
        this.records = camelizeMoodEntry(payload);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },
  }),
});
