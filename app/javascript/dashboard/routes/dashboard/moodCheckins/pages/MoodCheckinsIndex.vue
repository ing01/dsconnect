<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import format from 'date-fns/format';
import subDays from 'date-fns/subDays';
import { useMapGetter } from 'dashboard/composables/store';
import { useMoodEntriesStore } from 'dashboard/stores/moodEntries';
import { MOOD_OPTIONS, getMoodOption } from 'dashboard/constants/moods';

import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import Select from 'dashboard/components-next/select/Select.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const moodEntriesStore = useMoodEntriesStore();
const agents = useMapGetter('agents/getAgents');

const customDateRange = ref([subDays(new Date(), 29), new Date()]);
const selectedDateRangeType = ref(DATE_RANGE_TYPES.LAST_30_DAYS);
const selectedAgentId = ref('');
const selectedMoods = ref([]);

const isFetching = computed(() => moodEntriesStore.uiFlags.fetchingList);
const entries = computed(() => moodEntriesStore.records);

const agentOptions = computed(() => [
  { value: '', label: t('MOOD_CHECKINS.FILTERS.ALL_AGENTS') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);

const moodCounts = computed(() => {
  const counts = Object.fromEntries(MOOD_OPTIONS.map(({ value }) => [value, 0]));
  entries.value.forEach(entry => {
    if (counts[entry.mood] !== undefined) counts[entry.mood] += 1;
  });
  return counts;
});

const toggleMood = value => {
  selectedMoods.value = selectedMoods.value.includes(value)
    ? selectedMoods.value.filter(mood => mood !== value)
    : [...selectedMoods.value, value];
};

const formatDate = date => format(new Date(date), 'dd/MM/yyyy');

const fetchEntries = () => {
  moodEntriesStore.fetchAll({
    since: format(customDateRange.value[0], 'yyyy-MM-dd'),
    until: format(customDateRange.value[1], 'yyyy-MM-dd'),
    userId: selectedAgentId.value || undefined,
    mood: selectedMoods.value.length ? selectedMoods.value : undefined,
  });
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRangeType.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  fetchEntries();
};

watch([selectedAgentId, selectedMoods], fetchEntries, { deep: true });

onMounted(fetchEntries);
</script>

<template>
  <div class="flex flex-col gap-6 p-6 overflow-auto">
    <div class="flex flex-col gap-1">
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('MOOD_CHECKINS.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('MOOD_CHECKINS.SUBTITLE') }}
      </p>
    </div>

    <div class="flex flex-col gap-3">
      <div class="flex flex-wrap items-center gap-3">
        <WootDatePicker
          v-model:date-range="customDateRange"
          v-model:range-type="selectedDateRangeType"
          @date-range-changed="onDateRangeChange"
        />
        <Select
          v-model="selectedAgentId"
          :options="agentOptions"
          :aria-label="t('MOOD_CHECKINS.FILTERS.AGENT')"
        />
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <button
          v-for="mood in MOOD_OPTIONS"
          :key="mood.value"
          type="button"
          class="flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-sm transition-colors"
          :class="
            selectedMoods.includes(mood.value)
              ? 'bg-n-blue-3 border-n-blue-6 text-n-blue-11'
              : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-1'
          "
          @click="toggleMood(mood.value)"
        >
          <span>{{ mood.emoji }}</span>
          <span>{{ t(mood.labelKey) }}</span>
          <span class="text-xs font-medium tabular-nums">
            {{ moodCounts[mood.value] }}
          </span>
        </button>
      </div>
    </div>

    <div v-if="isFetching" class="flex items-center justify-center py-10 text-n-slate-11">
      <Spinner />
    </div>

    <div v-else-if="entries.length > 0" class="flex flex-col divide-y divide-n-weak">
      <div
        v-for="entry in entries"
        :key="entry.id"
        class="grid grid-cols-3 items-center gap-3 py-2.5"
      >
        <div class="flex items-center gap-2 min-w-0">
          <Avatar
            :name="entry.user.name"
            :src="entry.user.avatarUrl"
            :size="24"
            rounded-full
          />
          <span class="text-sm text-n-slate-12 truncate">{{ entry.user.name }}</span>
        </div>
        <div class="flex items-center gap-1.5 text-sm text-n-slate-12">
          <span>{{ getMoodOption(entry.mood)?.emoji }}</span>
          <span>{{ t(getMoodOption(entry.mood)?.labelKey) }}</span>
        </div>
        <span class="text-sm text-n-slate-11 justify-self-end">
          {{ formatDate(entry.entryDate) }}
        </span>
      </div>
    </div>

    <p
      v-else
      class="py-8 px-4 text-sm text-center rounded-xl border border-dashed border-n-strong text-n-slate-11"
    >
      {{ t('MOOD_CHECKINS.EMPTY_STATE') }}
    </p>
  </div>
</template>
