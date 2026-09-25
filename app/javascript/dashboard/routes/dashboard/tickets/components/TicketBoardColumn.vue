<script>
import Draggable from 'vuedraggable';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketCard from './TicketCard.vue';
import { ticketMatchesFilters } from '../helpers/ticketFilters';

export default {
  components: { Draggable, Icon, TicketCard },
  props: {
    column: { type: Object, required: true },
    tickets: { type: Array, required: true },
    agents: { type: Array, default: () => [] },
    isCollapsed: { type: Boolean, default: false },
    // Filters are applied visually (v-show) rather than by shrinking the
    // array bound to `Draggable`, so drag-and-drop keeps computing
    // positions against the column's real, full ticket list even while a
    // filter is active - only what's rendered is affected.
    filters: { type: Object, default: () => ({}) },
  },
  emits: [
    'addTicket',
    'openTicket',
    'moveTicket',
    'toggleCollapse',
    'menuAction',
  ],
  computed: {
    // Counts the tickets actually shown, so the badge always agrees with the
    // cards below it. Reads the live `tickets` array that Draggable mutates on
    // drop, which is what makes the number move the instant a card lands - and
    // that same array is what the board refetch and realtime upserts replace,
    // so it stays right after a reload too.
    visibleCount() {
      return this.tickets.filter(ticket => this.isVisible(ticket)).length;
    },
    // Collapsing is the only action left in the column header, so the control is
    // a comfortable 32x32 hit area rather than a bare icon: `flex-shrink-0` keeps
    // it that size no matter how long the stage name is.
    toggleButtonClass() {
      return [
        'flex flex-shrink-0 items-center justify-center size-8 rounded-lg',
        'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-slate-4',
        'transition-colors cursor-pointer',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand',
      ];
    },
    // Same hit area as the collapse control, tinted so "add ticket" reads as the
    // affirmative action of the pair.
    addButtonClass() {
      return [
        'flex flex-shrink-0 items-center justify-center size-8 rounded-lg',
        'text-n-teal-11 hover:text-n-teal-12 hover:bg-n-teal-3',
        'transition-colors cursor-pointer',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand',
      ];
    },
  },
  methods: {
    isVisible(ticket) {
      return ticketMatchesFilters(ticket, this.filters);
    },
    onChange(evt) {
      if (evt.added) {
        this.$emit('moveTicket', {
          ticketId: evt.added.element.id,
          ticketColumnId: this.column.id,
          position: evt.added.newIndex,
        });
      } else if (evt.moved) {
        this.$emit('moveTicket', {
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
    class="flex flex-col flex-shrink-0 rounded-xl bg-n-slate-2 max-h-full transition-[width] duration-150"
    :class="isCollapsed ? 'w-14 h-full' : 'w-72'"
  >
    <!-- Collapsed: expand button on top, then the counter, then the rotated
         name filling whatever height is left - stacked rather than overlapping,
         so the button stays the easiest thing to hit. -->
    <div
      v-if="isCollapsed"
      class="flex flex-col items-center gap-3 py-3 flex-1 min-h-0"
    >
      <button
        v-tooltip="$t('TICKET.BOARD.EXPAND')"
        type="button"
        :class="toggleButtonClass"
        :aria-label="$t('TICKET.BOARD.EXPAND_COLUMN', { name: column.name })"
        @click.stop="$emit('toggleCollapse', column.id)"
      >
        <Icon icon="i-lucide-panel-left-open" class="size-5" />
      </button>
      <!-- Name turned on its side, reading top to bottom, and given the leftover
           height so the counter settles at the bottom of the column. This is why
           the collapsed column takes `h-full`: without a definite height there
           would be no leftover to hand out and the name would collapse to 0. -->
      <span
        class="text-sm font-medium text-n-slate-12 [writing-mode:vertical-rl] truncate flex-1 min-h-0"
        :title="column.name"
      >
        {{ column.name }}
      </span>
      <span
        class="text-xs font-medium text-n-slate-11 bg-n-slate-4 rounded-full px-1.5 py-0.5 flex-shrink-0"
      >
        {{ visibleCount }}
      </span>
    </div>

    <template v-else>
      <div class="flex items-center justify-between gap-2 ps-3 pe-2 py-2">
        <div class="flex items-center gap-2 min-w-0">
          <span
            class="text-sm font-medium text-n-slate-12 truncate"
            :title="column.name"
          >
            {{ column.name }}
          </span>
          <span
            class="text-xs font-medium text-n-slate-11 bg-n-slate-4 rounded-full px-1.5 py-0.5 flex-shrink-0"
          >
            {{ visibleCount }}
          </span>
        </div>
        <div class="flex items-center gap-1 flex-shrink-0">
          <button
            v-tooltip="$t('TICKET.BOARD.COLLAPSE')"
            type="button"
            :class="toggleButtonClass"
            :aria-label="
              $t('TICKET.BOARD.COLLAPSE_COLUMN', { name: column.name })
            "
            @click.stop="$emit('toggleCollapse', column.id)"
          >
            <Icon icon="i-lucide-panel-left-close" class="size-5" />
          </button>
          <button
            v-tooltip="$t('TICKET.BOARD.ADD_TICKET')"
            type="button"
            :class="addButtonClass"
            :aria-label="
              $t('TICKET.BOARD.ADD_TICKET_TO_COLUMN', { name: column.name })
            "
            @click.stop="$emit('addTicket', column)"
          >
            <Icon icon="i-lucide-plus" class="size-5" />
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
            :is-completed="column.kind === 'completed'"
            @click="$emit('openTicket', element)"
            @menu-action="$emit('menuAction', $event)"
          />
        </template>
      </Draggable>
    </template>
  </div>
</template>

<style scoped lang="scss">
.ghost {
  @apply opacity-50 bg-n-slate-3 dark:bg-n-slate-9;
}
</style>
