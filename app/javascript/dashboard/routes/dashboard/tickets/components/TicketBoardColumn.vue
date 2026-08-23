<script>
import Draggable from 'vuedraggable';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketCard from './TicketCard.vue';
import { ticketMatchesFilters } from '../helpers/ticketFilters';

export default {
  components: {
    Draggable,
    Icon,
    TicketCard,
  },
  props: {
    column: {
      type: Object,
      required: true,
    },
    tickets: {
      type: Array,
      required: true,
    },
    agents: {
      type: Array,
      default: () => [],
    },
    isAdmin: {
      type: Boolean,
      default: false,
    },
    // Filters are applied visually (v-show) rather than by shrinking the
    // array bound to `Draggable`, so drag-and-drop keeps computing
    // positions against the column's real, full ticket list even while a
    // filter is active - only what's rendered is affected.
    filters: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: [
    'add-ticket',
    'open-ticket',
    'edit-ticket',
    'edit-column',
    'delete-column',
    'move-ticket',
    'open-conversation',
    'resolve-ticket',
    'reopen-ticket',
    'close-ticket',
  ],
  computed: {
    visibleCount() {
      return this.tickets.filter(ticket => this.isVisible(ticket)).length;
    },
  },
  methods: {
    isVisible(ticket) {
      return ticketMatchesFilters(ticket, this.filters);
    },
    onChange(evt) {
      if (evt.added) {
        this.$emit('move-ticket', {
          ticketId: evt.added.element.id,
          ticketColumnId: this.column.id,
          position: evt.added.newIndex,
        });
      } else if (evt.moved) {
        this.$emit('move-ticket', {
          ticketId: evt.moved.element.id,
          ticketColumnId: this.column.id,
          position: evt.moved.newIndex,
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col w-72 flex-shrink-0 rounded-xl bg-n-slate-2 max-h-full"
  >
    <div
      class="column-drag-handle flex items-center justify-between gap-2 px-3 py-2.5 cursor-grab"
    >
      <div class="flex items-center gap-2 min-w-0">
        <span class="text-sm font-medium text-n-slate-12 truncate">
          {{ column.name }}
        </span>
        <span
          class="text-xs text-n-slate-10 bg-n-slate-4 rounded-full px-1.5 py-0.5"
        >
          {{ visibleCount }}
        </span>
      </div>
      <div v-if="isAdmin" class="flex items-center gap-1">
        <button
          type="button"
          class="flex items-center justify-center size-6 rounded-md hover:bg-n-slate-4"
          @click.stop="$emit('edit-column', column)"
        >
          <Icon icon="i-lucide-pencil" class="size-3.5 text-n-slate-11" />
        </button>
        <button
          type="button"
          class="flex items-center justify-center size-6 rounded-md hover:bg-n-slate-4"
          @click.stop="$emit('delete-column', column)"
        >
          <Icon icon="i-lucide-trash-2" class="size-3.5 text-n-slate-11" />
        </button>
      </div>
    </div>

    <Draggable
      :list="tickets"
      group="tickets"
      item-key="id"
      animation="200"
      ghost-class="ghost"
      class="flex flex-col gap-2 px-2 pb-2 overflow-y-auto min-h-[2rem] flex-1"
      @change="onChange"
    >
      <template #item="{ element }">
        <TicketCard
          v-show="isVisible(element)"
          :ticket="element"
          :agents="agents"
          @click="$emit('open-ticket', element)"
          @edit="$emit('edit-ticket', element)"
          @open-conversation="$emit('open-conversation', element)"
          @resolve="$emit('resolve-ticket', element)"
          @reopen="$emit('reopen-ticket', element)"
          @close="$emit('close-ticket', element)"
        />
      </template>
    </Draggable>

    <button
      type="button"
      class="flex items-center gap-1.5 mx-2 mb-2 px-2 py-1.5 rounded-md text-sm text-n-slate-11 hover:bg-n-slate-4"
      @click="$emit('add-ticket', column)"
    >
      <Icon icon="i-lucide-plus" class="size-3.5" />
      {{ $t('TICKET.BOARD.ADD_TICKET') }}
    </button>
  </div>
</template>

<style scoped lang="scss">
.ghost {
  @apply opacity-50 bg-n-slate-3 dark:bg-n-slate-9;
}
</style>
