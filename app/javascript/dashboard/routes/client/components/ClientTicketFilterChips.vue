<script setup>
/**
 * Os filtros que estão valendo na lista, um chip para cada, com um "x" para tirar
 * só aquele. Quem olha a lista vê POR QUE ela está recortada sem abrir o modal.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { describeActive } from '../clientTicketFilters';

const props = defineProps({
  filters: { type: Object, required: true },
  teams: { type: Array, default: () => [] },
  ticketColumns: { type: Array, default: () => [] },
  assignees: { type: Array, default: () => [] },
});

defineEmits(['remove', 'clear']);

const { t } = useI18n();

const chips = computed(() =>
  describeActive(
    props.filters,
    {
      teams: props.teams,
      ticketColumns: props.ticketColumns,
      assignees: props.assignees,
    },
    t
  )
);
</script>

<template>
  <div v-if="chips.length" class="flex flex-wrap items-center w-full gap-2 min-w-0">
    <span
      v-for="chip in chips"
      :key="chip.key"
      class="inline-flex items-center h-7 gap-1 pl-3 pr-1 text-xs border rounded-full border-n-weak bg-n-alpha-2 text-n-slate-12"
    >
      <span class="truncate max-w-56">{{ chip.label }}</span>
      <button
        type="button"
        class="flex items-center justify-center rounded-full size-5 text-n-slate-10 hover:bg-n-alpha-3 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CLIENT_AREA.BOARD.FILTERS.REMOVE', { filter: chip.label })"
        @click="$emit('remove', chip.key)"
      >
        <Icon icon="i-lucide-x" class="size-3" />
      </button>
    </span>

    <button
      type="button"
      class="h-7 px-2 text-xs rounded-lg text-n-brand hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      @click="$emit('clear')"
    >
      {{ t('CLIENT_AREA.BOARD.CLEAR_FILTERS') }}
    </button>
  </div>
</template>
