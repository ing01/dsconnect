<script setup>
import { ref } from 'vue';
import { format, fromUnixTime } from 'date-fns';
import CopilotThreadOrigin from './CopilotThreadOrigin.vue';

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

const emit = defineEmits(['select', 'loadMore', 'delete']);

// A conversa que esta pedindo confirmacao para ser excluida (o pedido fica
// na propria linha, sem abrir dialogo por cima do painel estreito).
const confirmingId = ref(null);

const confirmDelete = thread => {
  confirmingId.value = null;
  emit('delete', thread);
};

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

    <div
      v-for="thread in threads"
      :key="thread.id"
      class="flex flex-col gap-1.5 w-full px-3 py-2 rounded-lg border border-n-weak bg-n-slate-2 hover:bg-n-slate-3 transition-colors"
    >
      <div class="flex items-start gap-2">
        <button
          type="button"
          class="flex flex-col gap-0.5 min-w-0 grow text-left"
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
          type="button"
          class="shrink-0 p-1 rounded text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-alpha-2"
          :title="$t('CAPTAIN.COPILOT.HISTORY.DELETE')"
          :aria-label="$t('CAPTAIN.COPILOT.HISTORY.DELETE')"
          @click="confirmingId = thread.id"
        >
          <span class="i-lucide-trash-2 block size-4" />
        </button>
      </div>
      <div
        v-if="confirmingId === thread.id"
        class="flex items-center justify-between gap-2 px-2 py-1.5 text-xs rounded-md bg-n-ruby-3 text-n-ruby-11"
      >
        <span>{{ $t('CAPTAIN.COPILOT.HISTORY.DELETE_CONFIRM') }}</span>
        <span class="flex items-center gap-2 shrink-0">
          <button
            type="button"
            class="font-semibold hover:underline"
            @click="confirmDelete(thread)"
          >
            {{ $t('CAPTAIN.COPILOT.HISTORY.DELETE_YES') }}
          </button>
          <button
            type="button"
            class="hover:underline"
            @click="confirmingId = null"
          >
            {{ $t('CAPTAIN.COPILOT.HISTORY.DELETE_NO') }}
          </button>
        </span>
      </div>
      <CopilotThreadOrigin :thread="thread" />
    </div>

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
