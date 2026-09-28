<script setup>
import { computed } from 'vue';
import { format, parseISO } from 'date-fns';

const props = defineProps({
  suggestion: { type: Object, required: true },
});

defineEmits(['click']);

const dateLabel = computed(() =>
  props.suggestion.created_at
    ? format(parseISO(props.suggestion.created_at), 'dd/MM/yyyy')
    : ''
);
</script>

<template>
  <div
    class="drag-handle flex flex-col gap-2 rounded-xl border border-n-weak bg-n-solid-1 p-3 cursor-pointer hover:border-n-slate-6 hover:shadow-sm transition-shadow"
    @click="$emit('click', suggestion)"
  >
    <p class="text-sm font-medium text-n-slate-12 line-clamp-2 mb-0">
      {{ suggestion.title }}
    </p>
    <p
      v-if="suggestion.description"
      class="text-xs text-n-slate-11 line-clamp-3 mb-0"
    >
      {{ suggestion.description }}
    </p>
    <div
      v-if="suggestion.assignee_name"
      class="flex items-center gap-1 text-xs text-n-teal-11"
    >
      <span
        class="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-teal-3 text-[10px] font-medium text-n-teal-11"
      >
        {{ suggestion.assignee_name.charAt(0).toUpperCase() }}
      </span>
      <span class="truncate">{{ suggestion.assignee_name }}</span>
    </div>
    <div class="flex items-center justify-between gap-2">
      <div v-if="suggestion.user_name" class="flex items-center gap-1.5 min-w-0">
        <span
          class="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-slate-4 text-[10px] font-medium text-n-slate-12"
        >
          {{ suggestion.user_name.charAt(0).toUpperCase() }}
        </span>
        <span class="text-xs text-n-slate-11 truncate">
          {{ suggestion.user_name }}
        </span>
      </div>
      <div v-else />
      <span class="text-xs text-n-slate-10 flex-shrink-0">{{ dateLabel }}</span>
    </div>
  </div>
</template>
