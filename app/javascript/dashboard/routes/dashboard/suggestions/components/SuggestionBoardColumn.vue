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

// `added` e o card que veio de outra coluna; `moved`, o que trocou de lugar
// dentro desta. Os dois viram o mesmo pedido: este card, nesta coluna, nesta
// posicao.
const onChange = evt => {
  const change = evt.added || evt.moved;
  if (!change) return;

  emit('moveSuggestion', {
    suggestionId: change.element.id,
    suggestionColumnId: props.column.id,
    position: change.newIndex,
  });
};
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 w-72 max-h-full rounded-xl bg-n-slate-2"
  >
    <!-- A coluna e VERTICAL e tem largura fixa: cabecalho em cima, cards
         embaixo. O quadro rola na horizontal (`overflow-x-auto`), e para isso
         cada coluna precisa de `w-72` e `flex-shrink-0` - sem os dois, elas se
         comprimiriam umas contra as outras em vez de o quadro rolar. Mesmo
         molde do Kanban de Tickets (TicketBoardColumn). -->
    <div
      class="flex items-center flex-shrink-0 gap-2 px-3 py-2 min-w-0 rounded-t-xl"
      :class="column.completed ? 'bg-n-teal-9' : 'border-b border-n-weak'"
    >
      <span
        class="text-sm font-medium truncate"
        :class="column.completed ? 'text-white' : 'text-n-slate-12'"
        :title="column.name"
      >
        {{ column.name }}
      </span>
      <!-- O contador acompanha o fundo do cabecalho: na coluna de concluido o
           fundo e escuro, e o cinza claro das outras ficaria ilegivel ali. -->
      <span
        class="flex items-center justify-center flex-shrink-0 min-w-[20px] h-5 px-1.5 rounded-full text-xs font-medium"
        :class="
          column.completed
            ? 'bg-white/20 text-white'
            : 'bg-n-slate-4 text-n-slate-11'
        "
      >
        {{ count }}
      </span>
    </div>

    <Draggable
      :list="suggestions"
      :disabled="readOnly"
      group="suggestions"
      item-key="id"
      animation="200"
      ghost-class="ghost"
      class="flex flex-col flex-1 gap-2 px-2 py-2 overflow-y-auto min-h-[2rem]"
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
</template>

<style scoped lang="scss">
.ghost {
  @apply opacity-50 bg-n-slate-3 dark:bg-n-slate-9;
}
</style>
