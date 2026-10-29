<script setup>
import { format, fromUnixTime } from 'date-fns';

defineProps({
  threads: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  hasError: {
    type: Boolean,
    default: false,
  },
  canLoadMore: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['select', 'loadMore']);

const formatDate = createdAt =>
  format(fromUnixTime(createdAt), 'dd/MM/yyyy HH:mm');
</script>

<template>
  <div class="flex flex-col gap-2 w-full">
    <p v-if="isLoading && !threads.length" class="text-sm text-n-slate-11">
      {{ $t('CAPTAIN.COPILOT.HISTORY.LOADING') }}
    </p>
    <p v-else-if="hasError" class="text-sm text-n-ruby-11">
      {{ $t('CAPTAIN.COPILOT.HISTORY.LOAD_ERROR') }}
    </p>
    <p v-else-if="!threads.length" class="text-sm text-n-slate-11">
      {{ $t('CAPTAIN.COPILOT.HISTORY.EMPTY') }}
    </p>

    <button
      v-for="thread in threads"
      :key="thread.id"
      type="button"
      class="flex flex-col gap-0.5 w-full px-3 py-2 text-left rounded-lg border border-n-weak bg-n-slate-2 hover:bg-n-slate-3 transition-colors"
      @click="emit('select', thread)"
    >
      <span class="text-sm text-n-slate-12 line-clamp-2">{{
        thread.title
      }}</span>
      <span class="text-xs text-n-slate-10">{{
        formatDate(thread.created_at)
      }}</span>
    </button>

    <button
      v-if="canLoadMore"
      type="button"
      class="self-center mt-1 text-xs text-n-blue-11 hover:underline disabled:opacity-60"
      :disabled="isLoading"
      @click="emit('loadMore')"
    >
      {{ $t('CAPTAIN.COPILOT.HISTORY.LOAD_MORE') }}
    </button>
  </div>
</template>
