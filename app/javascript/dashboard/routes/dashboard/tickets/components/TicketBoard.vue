<script>
import TicketBoardColumn from './TicketBoardColumn.vue';
import {
  readCollapsedColumnIds,
  toggleCollapsedColumn,
} from '../helpers/collapsedColumns';
import { sortTickets } from '../helpers/ticketSort';

export default {
  components: {
    TicketBoardColumn,
  },
  props: {
    board: {
      type: Object,
      required: true,
    },
    accountId: {
      type: [Number, String],
      required: true,
    },
    teamId: {
      type: [Number, String],
      required: true,
    },
    agents: {
      type: Array,
      default: () => [],
    },
    filters: {
      type: Object,
      default: () => ({}),
    },
    sort: {
      type: Object,
      default: null,
    },
  },
  emits: ['addTicket', 'openTicket', 'moveTicket', 'menuAction'],
  data() {
    return {
      // Estagios are ordered by the backend and reordered from Settings, so the
      // board only keeps the ticket arrays locally - Draggable mutates those in
      // place, which is what keeps each column's counter correct mid-drag.
      localColumns: {},
      columns: [],
      collapsedColumnIds: [],
    };
  },
  watch: {
    board: {
      immediate: true,
      handler(newBoard) {
        this.syncLocalState(newBoard);
      },
    },
    // Re-sorting goes through the same path a refetch does, so a board that is
    // already loaded reorders without another request.
    sort() {
      this.syncLocalState(this.board);
    },
  },
  methods: {
    syncLocalState(board) {
      const columns = board?.ticket_columns || [];
      this.columns = columns.map(column => ({ ...column }));

      // Sorting is applied here, on the way into the local arrays, which is the
      // single point every path funnels through: first load, realtime upserts and
      // the refetch that follows a drag all land back in an ordered column.
      const columnTickets = {};
      columns.forEach(column => {
        columnTickets[column.id] = sortTickets(column.tickets || [], this.sort);
      });
      this.localColumns = columnTickets;

      this.collapsedColumnIds = readCollapsedColumnIds(
        this.accountId,
        this.teamId,
        this.columns.map(column => column.id)
      );
    },
    isCollapsed(columnId) {
      return this.collapsedColumnIds.includes(columnId);
    },
    toggleColumn(columnId) {
      this.collapsedColumnIds = toggleCollapsedColumn(
        this.accountId,
        this.teamId,
        columnId
      );
    },
  },
};
</script>

<template>
  <div
    class="w-full max-w-full min-w-0 h-full overflow-x-auto overflow-y-hidden"
  >
    <!-- Outer div is the viewport: it owns the horizontal scroll and is capped at
         the width the page hands it, so no number of Estagios can widen the page
         or push the header out of reach. The inner strip is `w-max` so columns
         keep their usable width and simply extend past the viewport instead of
         being squeezed to fit. -->
    <div class="flex h-full w-max gap-3 pb-2 items-start">
      <TicketBoardColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :tickets="localColumns[column.id] || []"
        :agents="agents"
        :filters="filters"
        :is-collapsed="isCollapsed(column.id)"
        @toggle-collapse="toggleColumn"
        @add-ticket="$emit('addTicket', $event)"
        @open-ticket="$emit('openTicket', $event)"
        @move-ticket="$emit('moveTicket', $event)"
        @menu-action="$emit('menuAction', $event)"
      />
    </div>
  </div>
</template>
