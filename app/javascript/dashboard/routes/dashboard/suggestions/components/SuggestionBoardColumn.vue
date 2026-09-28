<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import SuggestionCard from './SuggestionCard.vue';

const props = defineProps({
  column: { type: Object, required: true },
  suggestions: { type: Array, default: () => [] },
  // Quem nao tem `suggestion_manage` (nem e administrador) ve o quadro mas
  // nao arrasta cards - a trava de verdade e no backend (SuggestionPolicy),
  // isso aqui so evita a tentativa.
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['openSuggestion', 'moveSuggestion']);

const count = computed(() => props.suggestions.length);

const onChange = evt => {
  if (evt.added) {
    emit('moveSuggestion', {
      suggestionId: evt.added.element.id,
      suggestionColumnId: props.column.id,
      position: evt.added.newIndex,
    });
  } else if (evt.moved) {
    emit('moveSuggestion', {
      suggestionId: evt.moved.element.id,
      suggestionColumnId: props.column.id,
      position: evt.moved.newIndex,
    });
  }
};
</script>

<template>
  <div
    class="flex items-center gap-2 px-3 py-2.5 rounded-t-xl"
    :class="
      column.completed
        ? 'bg-green-600'
        : 'border-b border-n-weak'
    "
  >
    <div
      class="flex items-center gap-2 px-3 py-2.5 rounded-t-xl"
      :class="column.completed ? 'bg-n-teal-9' : 'border-b border-n-weak'"
    >
      <span
        class="text-sm font-semibold truncate"
        :class="column.completed ? 'text-white' : 'text-n-slate-12'"
      >
        {{ column.name }}
      </span>
      <span
        class="flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-full text-[11px] font-medium"
        :class="
            column.completed
              ? 'bg-green-50 border-green-300'
              : 'bg-n-slate-2/60 border-n-weak'
          "
      >
        {{ count }}
      </span>
    </div>

    <div class="flex-1 overflow-y-auto p-2 min-h-0">
      <Draggable
        :list="suggestions"
        :disabled="readOnly"
        group="suggestions"
        item-key="id"
        animation="200"
        ghost-class="opacity-50"
        class="flex flex-col gap-2 min-h-[50px]"
        @change="onChange"
      >
        <template #item="{ element }">
          <SuggestionCard
            :suggestion="element"
            @click="emit('openSuggestion', element)"
          />
        </template>
      </Draggable>
    </div>
  </div>
</template>
