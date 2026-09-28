<script setup>
import SuggestionBoardColumn from './SuggestionBoardColumn.vue';

const props = defineProps({
  columns: { type: Array, default: () => [] },
  suggestions: { type: Array, default: () => [] },
  readOnly: { type: Boolean, default: false },
});

defineEmits(['openSuggestion', 'moveSuggestion']);

const suggestionsForColumn = columnId =>
  props.suggestions
    .filter(suggestion => suggestion.suggestion_column_id === columnId)
    .sort((a, b) => a.position - b.position);
</script>

<template>
  <div class="flex flex-1 gap-4 overflow-x-auto min-h-0 pb-2">
    <SuggestionBoardColumn
      v-for="column in columns"
      :key="column.id"
      :column="column"
      :suggestions="suggestionsForColumn(column.id)"
      :read-only="readOnly"
      @open-suggestion="$emit('openSuggestion', $event)"
      @move-suggestion="$emit('moveSuggestion', $event)"
    />
  </div>
</template>
