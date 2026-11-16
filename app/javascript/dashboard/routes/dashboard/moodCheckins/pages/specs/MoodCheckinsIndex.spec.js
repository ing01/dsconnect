import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import format from 'date-fns/format';
import MoodCheckinsIndex from '../MoodCheckinsIndex.vue';

const { fetchAll } = vi.hoisted(() => ({ fetchAll: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref([]),
}));
vi.mock('dashboard/stores/moodEntries', () => ({
  useMoodEntriesStore: () => ({
    uiFlags: { fetchingList: false },
    records: [],
    fetchAll,
  }),
}));

describe('MoodCheckinsIndex', () => {
  beforeEach(() => vi.clearAllMocks());

  // O relatorio abre no dia de hoje, sem a pessoa precisar mexer no periodo.
  it('opens already filtered on today (today until today)', () => {
    shallowMount(MoodCheckinsIndex);

    const today = format(new Date(), 'yyyy-MM-dd');
    expect(fetchAll).toHaveBeenCalledWith(
      expect.objectContaining({ since: today, until: today })
    );
  });
});
