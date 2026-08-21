<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMoodEntriesStore } from 'dashboard/stores/moodEntries';
import { useAlert } from 'dashboard/composables';
import { MOOD_OPTIONS } from 'dashboard/constants/moods';

const { t } = useI18n();
const moodEntriesStore = useMoodEntriesStore();

const dismissed = ref(false);

const todayChecked = computed(() => moodEntriesStore.todayChecked);
const todayEntry = computed(() => moodEntriesStore.todayEntry);

const shouldShowBanner = computed(() => {
  if (dismissed.value) return false;
  if (!todayChecked.value) return false;
  return !todayEntry.value;
});

const dismissBanner = () => {
  dismissed.value = true;
};

const selectMood = async mood => {
  try {
    await moodEntriesStore.create(mood.value);
  } catch (error) {
    useAlert(t('MOOD_CHECKIN.ERROR'));
  }
};

onMounted(() => {
  moodEntriesStore.fetchToday();
});
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div
    v-if="shouldShowBanner"
    class="flex items-center justify-between gap-3 px-4 py-2 text-sm border-b bg-n-blue-3 border-n-blue-4 text-n-blue-11"
  >
    <div class="flex items-center min-w-0 gap-2">
      <span class="shrink-0 i-lucide-smile size-4" />
      <span class="truncate">{{ t('MOOD_CHECKIN.TITLE') }}</span>
    </div>
    <div class="flex items-center gap-1 shrink-0">
      <button
        v-for="mood in MOOD_OPTIONS"
        :key="mood.value"
        type="button"
        class="grid rounded-lg size-8 place-content-center text-lg hover:bg-n-blue-4 transition-colors"
        :title="t(mood.labelKey)"
        :aria-label="t(mood.labelKey)"
        @click="selectMood(mood)"
      >
        {{ mood.emoji }}
      </button>
      <button
        type="button"
        class="grid rounded-lg size-7 place-content-center hover:bg-n-blue-4"
        :aria-label="t('MOOD_CHECKIN.SKIP')"
        @click="dismissBanner"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>
  </div>
</template>
