<script>
import Draggable from 'vuedraggable';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketBoardColumn from './TicketBoardColumn.vue';

export default {
  components: {
    Draggable,
    Icon,
    TicketBoardColumn,
  },
  props: {
    board: {
      type: Object,
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
    filters: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: [
    'add-ticket',
    'open-ticket',
    'edit-ticket',
    'add-column',
    'edit-column',
    'delete-column',
    'move-ticket',
    'reorder-columns',
    'open-conversation',
    'resolve-ticket',
    'reopen-ticket',
    'close-ticket',
  ],
  data() {
    return {
      localColumns: {},
      localColumnOrder: [],
    };
  },
  watch: {
    board: {
      immediate: true,
      handler(newBoard) {
        this.syncLocalState(newBoard);
      },
    },
  },
  methods: {
    syncLocalState(board) {
      const columns = board?.ticket_columns || [];
      this.localColumnOrder = columns.map(column => ({ ...column }));

      const columnTickets = {};
      columns.forEach(column => {
        columnTickets[column.id] = [...(column.tickets || [])];
      });
      this.localColumns = columnTickets;
    },
    onColumnsDragEnd() {
      this.$emit(
        'reorder-columns',
        this.localColumnOrder.map(column => column.id)
      );
    },
  },
};
</script>

<template>
  <div class="flex h-full gap-3 overflow-x-auto pb-2">
    <Draggable
      v-model="localColumnOrder"
      item-key="id"
      animation="200"
      handle=".column-drag-handle"
      class="flex gap-3 items-start"
      @end="onColumnsDragEnd"
    >
      <template #item="{ element }">
        <TicketBoardColumn
          :column="element"
          :tickets="localColumns[element.id] || []"
          :agents="agents"
          :is-admin="isAdmin"
          :filters="filters"
          @add-ticket="$emit('add-ticket', $event)"
          @open-ticket="$emit('open-ticket', $event)"
          @edit-ticket="$emit('edit-ticket', $event)"
          @edit-column="$emit('edit-column', $event)"
          @delete-column="$emit('delete-column', $event)"
          @move-ticket="$emit('move-ticket', $event)"
          @open-conversation="$emit('open-conversation', $event)"
          @resolve-ticket="$emit('resolve-ticket', $event)"
          @reopen-ticket="$emit('reopen-ticket', $event)"
          @close-ticket="$emit('close-ticket', $event)"
        />
      </template>
    </Draggable>

    <button
      v-if="isAdmin"
      type="button"
      class="flex flex-shrink-0 items-center gap-1.5 h-10 px-3 rounded-xl border border-dashed border-n-weak text-sm text-n-slate-11 hover:bg-n-slate-2"
      @click="$emit('add-column')"
    >
      <Icon icon="i-lucide-plus" class="size-3.5" />
      {{ $t('TICKET.BOARD.ADD_COLUMN') }}
    </button>
  </div>
</template>
