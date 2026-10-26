<script setup>
import { computed, ref } from 'vue';
import Draggable from 'vuedraggable';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import BacklogTicketRow from './BacklogTicketRow.vue';
import { ticketMatchesFilters } from '../../helpers/ticketFilters';

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  tickets: { type: Array, required: true },
  agents: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  filters: { type: Object, default: () => ({}) },
  selectedIds: { type: Array, default: () => [] },
});

// `sprintId: null` identifica o balde do Backlog (sem sprint) - os demais
// baldes sao os Sprints, um por balde.
const emit = defineEmits([
  'openTicket',
  'moveTicket',
  'moveToColumn',
  'toggleSelect',
  'selectMany',
]);

const isCollapsed = ref(false);

// Filtro e' so' visual (v-show), nunca tira item da lista que o Draggable
// usa - do mesmo jeito que o Kanban faz (`TicketBoardColumn.vue`). Tirar de
// verdade confundiria o arrastar-e-soltar, que depende da lista completa.
const isVisible = ticket => ticketMatchesFilters(ticket, props.filters);

const visibleTickets = computed(() => props.tickets.filter(isVisible));
const visibleCount = computed(() => visibleTickets.value.length);

const isSelected = id => props.selectedIds.includes(id);

// Marca/desmarca TODOS os tickets visiveis deste balde de uma vez - sem
// mexer na selecao de outros baldes.
const allVisibleSelected = computed(
  () =>
    visibleTickets.value.length > 0 &&
    visibleTickets.value.every(ticket => isSelected(ticket.id))
);

const toggleSelectAll = () => {
  emit(
    'selectMany',
    visibleTickets.value.map(ticket => ticket.id),
    !allVisibleSelected.value
  );
};

// So' `evt.added` interessa aqui: um cartao que ENTROU neste balde, vindo de
// outro. `evt.moved` (reordenar dentro do mesmo balde) nao tem efeito no
// servidor - a ordem dentro do Backlog/Sprint nao e' um dado hoje.
const onChange = evt => {
  if (!evt.added) return;
  emit('moveTicket', evt.added.element.id);
};
</script>

<template>
  <section
    class="flex flex-col gap-2 rounded-xl border border-n-weak bg-n-solid-1 p-3 min-w-0"
  >
    <div class="flex items-center gap-2">
      <Checkbox
        v-if="visibleCount"
        :model-value="allVisibleSelected"
        class="flex-shrink-0"
        @change="toggleSelectAll"
      />
      <button
        type="button"
        class="flex items-center gap-2 text-left flex-1 min-w-0"
        @click="isCollapsed = !isCollapsed"
      >
        <Icon
          :icon="
            isCollapsed ? 'i-lucide-chevron-right' : 'i-lucide-chevron-down'
          "
          class="size-4 text-n-slate-10 flex-shrink-0"
        />
        <span class="text-sm font-medium text-n-slate-12 truncate">
          {{ title }}
        </span>
        <span v-if="subtitle" class="text-xs text-n-slate-10 truncate">
          {{ subtitle }}
        </span>
        <span
          class="text-xs text-n-slate-10 ltr:ml-auto rtl:mr-auto flex-shrink-0"
        >
          {{ visibleCount }}/{{ tickets.length }}
        </span>
      </button>
    </div>

    <Draggable
      v-show="!isCollapsed"
      :list="props.tickets"
      group="tickets"
      item-key="id"
      animation="200"
      ghost-class="ghost"
      class="flex flex-col gap-1 min-h-[2.5rem]"
      @change="onChange"
    >
      <template #item="{ element }">
        <BacklogTicketRow
          v-show="isVisible(element)"
          :ticket="element"
          :agents="agents"
          :columns="columns"
          :selected="isSelected(element.id)"
          @click="emit('openTicket', element)"
          @move-to-column="value => emit('moveToColumn', element.id, value)"
          @toggle-select="emit('toggleSelect', element.id)"
        />
      </template>
    </Draggable>
  </section>
</template>

<style scoped lang="scss">
.ghost {
  @apply opacity-50 bg-n-slate-3 dark:bg-n-slate-9;
}
</style>
