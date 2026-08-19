<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketBoard from '../components/TicketBoard.vue';
import TicketFormDialog from '../components/TicketFormDialog.vue';
import TicketColumnFormDialog from '../components/TicketColumnFormDialog.vue';
import TicketBoardFormDialog from '../components/TicketBoardFormDialog.vue';

const DEFAULT_COLUMN_NAMES = ['A fazer', 'Em andamento', 'Concluído'];

export default {
  components: {
    NextButton,
    Spinner,
    Icon,
    TicketBoard,
    TicketFormDialog,
    TicketColumnFormDialog,
    TicketBoardFormDialog,
  },
  data() {
    return {
      showTicketForm: false,
      showColumnForm: false,
      showBoardForm: false,
      showDeleteColumnConfirm: false,
      showDeleteBoardConfirm: false,
      isSubmittingTicket: false,
      isCreatingBoard: false,
      selectedTicket: null,
      selectedColumn: null,
      targetColumnId: null,
      selectedBoardId: null,
      editingBoard: null,
    };
  },
  computed: {
    ...mapGetters({
      boards: 'ticketBoards/getBoards',
      boardUIFlags: 'ticketBoards/getUIFlags',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      currentRole: 'getCurrentRole',
    }),
    board() {
      if (this.selectedBoardId) {
        const selected = this.boards.find(b => b.id === this.selectedBoardId);
        if (selected) return selected;
      }
      return this.boards[0] || null;
    },
    isAdmin() {
      return this.currentRole === 'administrator';
    },
    isLoading() {
      return this.boardUIFlags.isFetching && !this.board;
    },
  },
  mounted() {
    this.$store.dispatch('ticketBoards/get');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
  },
  methods: {
    selectBoard(boardId) {
      this.selectedBoardId = boardId;
    },
    async createBoardWithDefaultColumns(name) {
      const board = await this.$store.dispatch('ticketBoards/create', {
        name,
      });
      await Promise.all(
        DEFAULT_COLUMN_NAMES.map(columnName =>
          this.$store.dispatch('ticketBoards/createColumn', {
            boardId: board.id,
            name: columnName,
          })
        )
      );
      return board;
    },
    async createDefaultBoard() {
      this.isCreatingBoard = true;
      try {
        await this.createBoardWithDefaultColumns(this.$t('TICKET.HEADER'));
      } catch (error) {
        useAlert(this.$t('TICKET.API.BOARD_CREATE_ERROR'));
      } finally {
        this.isCreatingBoard = false;
      }
    },
    openAddBoard() {
      this.editingBoard = null;
      this.showBoardForm = true;
    },
    openEditBoard(board) {
      this.editingBoard = board;
      this.showBoardForm = true;
    },
    closeBoardForm() {
      this.showBoardForm = false;
      this.editingBoard = null;
    },
    async submitBoard(payload) {
      try {
        if (this.editingBoard) {
          await this.$store.dispatch('ticketBoards/update', {
            id: this.editingBoard.id,
            ...payload,
          });
        } else {
          const board = await this.createBoardWithDefaultColumns(
            payload.name
          );
          this.selectedBoardId = board.id;
        }
        useAlert(this.$t('TICKET.API.BOARD_SUCCESS'));
        this.closeBoardForm();
      } catch (error) {
        useAlert(this.$t('TICKET.API.BOARD_ERROR'));
      }
    },
    confirmDeleteBoard(board) {
      this.editingBoard = board;
      this.showDeleteBoardConfirm = true;
    },
    closeDeleteBoardConfirm() {
      this.showDeleteBoardConfirm = false;
      this.editingBoard = null;
    },
    async deleteBoardConfirmed() {
      const board = this.editingBoard;
      this.closeDeleteBoardConfirm();
      try {
        await this.$store.dispatch('ticketBoards/delete', board.id);
        if (this.selectedBoardId === board.id) {
          this.selectedBoardId = null;
        }
        useAlert(this.$t('TICKET.API.BOARD_DELETE_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('TICKET.API.BOARD_DELETE_ERROR'));
      }
    },
    openAddTicket(column) {
      this.selectedTicket = null;
      this.targetColumnId = column.id;
      this.showTicketForm = true;
    },
    openEditTicket(ticket) {
      this.selectedTicket = ticket;
      this.targetColumnId = ticket.ticket_column_id;
      this.showTicketForm = true;
    },
    closeTicketForm() {
      this.showTicketForm = false;
      this.selectedTicket = null;
      this.targetColumnId = null;
    },
    async submitTicket(payload) {
      this.isSubmittingTicket = true;
      try {
        if (this.selectedTicket) {
          await this.$store.dispatch('ticketBoards/updateTicket', {
            boardId: this.board.id,
            id: this.selectedTicket.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('ticketBoards/createTicket', {
            boardId: this.board.id,
            ticket_column_id: this.targetColumnId,
            ...payload,
          });
        }
        useAlert(this.$t('TICKET.API.SUCCESS_MESSAGE'));
        this.closeTicketForm();
      } catch (error) {
        useAlert(this.$t('TICKET.API.ERROR_MESSAGE'));
      } finally {
        this.isSubmittingTicket = false;
      }
    },
    openAddColumn() {
      this.selectedColumn = null;
      this.showColumnForm = true;
    },
    openEditColumn(column) {
      this.selectedColumn = column;
      this.showColumnForm = true;
    },
    closeColumnForm() {
      this.showColumnForm = false;
      this.selectedColumn = null;
    },
    async submitColumn(payload) {
      try {
        if (this.selectedColumn) {
          await this.$store.dispatch('ticketBoards/updateColumn', {
            boardId: this.board.id,
            columnId: this.selectedColumn.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('ticketBoards/createColumn', {
            boardId: this.board.id,
            ...payload,
          });
        }
        useAlert(this.$t('TICKET.API.COLUMN_SUCCESS'));
        this.closeColumnForm();
      } catch (error) {
        useAlert(this.$t('TICKET.API.COLUMN_ERROR'));
      }
    },
    confirmDeleteColumn(column) {
      this.selectedColumn = column;
      this.showDeleteColumnConfirm = true;
    },
    closeDeleteColumnConfirm() {
      this.showDeleteColumnConfirm = false;
      this.selectedColumn = null;
    },
    async deleteColumnConfirmed() {
      const column = this.selectedColumn;
      this.closeDeleteColumnConfirm();
      try {
        await this.$store.dispatch('ticketBoards/deleteColumn', {
          boardId: this.board.id,
          columnId: column.id,
        });
        useAlert(this.$t('TICKET.API.COLUMN_DELETE_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('TICKET.API.COLUMN_DELETE_ERROR'));
      }
    },
    async moveTicket({ ticketId, ticketColumnId, position }) {
      try {
        await this.$store.dispatch('ticketBoards/moveTicket', {
          boardId: this.board.id,
          id: ticketId,
          ticketColumnId,
          position,
        });
      } catch (error) {
        useAlert(this.$t('TICKET.API.MOVE_ERROR'));
      }
    },
    async reorderColumns(columnIds) {
      await this.$store.dispatch('ticketBoards/reorderColumns', {
        boardId: this.board.id,
        columnIds,
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0 p-4 gap-4">
    <div class="flex items-start justify-between gap-4 flex-shrink-0">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ $t('TICKET.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ $t('TICKET.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <div
      v-if="boards.length"
      class="flex items-center gap-1 border-b border-n-weak flex-shrink-0 overflow-x-auto"
    >
      <div
        v-for="item in boards"
        :key="item.id"
        class="group flex items-center gap-1.5 px-3 py-2 border-b-2 cursor-pointer flex-shrink-0"
        :class="
          board && item.id === board.id
            ? 'border-n-brand text-n-slate-12'
            : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
        "
        @click="selectBoard(item.id)"
      >
        <span class="text-sm font-medium whitespace-nowrap">{{
          item.name
        }}</span>
        <span
          v-if="isAdmin && board && item.id === board.id"
          class="hidden group-hover:flex items-center gap-0.5"
        >
          <button
            type="button"
            class="flex items-center justify-center size-5 rounded hover:bg-n-slate-4"
            @click.stop="openEditBoard(item)"
          >
            <Icon icon="i-lucide-pencil" class="size-3" />
          </button>
          <button
            type="button"
            class="flex items-center justify-center size-5 rounded hover:bg-n-slate-4"
            @click.stop="confirmDeleteBoard(item)"
          >
            <Icon icon="i-lucide-trash-2" class="size-3" />
          </button>
        </span>
      </div>
      <button
        v-if="isAdmin"
        type="button"
        class="flex items-center gap-1 px-2 py-1.5 text-sm text-n-slate-11 hover:text-n-slate-12 flex-shrink-0"
        @click="openAddBoard"
      >
        <Icon icon="i-lucide-plus" class="size-3.5" />
        {{ $t('TICKET.BOARD.NEW_BOARD') }}
      </button>
    </div>

    <div
      v-if="isLoading"
      class="flex items-center justify-center gap-2 flex-1 text-n-slate-11"
    >
      <Spinner />
      <span class="text-sm">{{ $t('TICKET.LOADING') }}</span>
    </div>

    <div
      v-else-if="!board"
      class="flex flex-1 flex-col items-center justify-center gap-3 text-center"
    >
      <h2 class="text-base font-medium text-n-slate-12">
        {{ $t('TICKET.EMPTY.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-11 max-w-sm">
        {{ $t('TICKET.EMPTY.DESC') }}
      </p>
      <NextButton
        v-if="isAdmin"
        :label="$t('TICKET.EMPTY.ACTION')"
        :is-loading="isCreatingBoard"
        @click="createDefaultBoard"
      />
    </div>

    <TicketBoard
      v-else
      :board="board"
      :agents="agents"
      :is-admin="isAdmin"
      class="flex-1 min-h-0"
      @add-ticket="openAddTicket"
      @edit-ticket="openEditTicket"
      @add-column="openAddColumn"
      @edit-column="openEditColumn"
      @delete-column="confirmDeleteColumn"
      @move-ticket="moveTicket"
      @reorder-columns="reorderColumns"
    />

    <woot-modal v-model:show="showTicketForm" :on-close="closeTicketForm">
      <TicketFormDialog
        :ticket="selectedTicket"
        :agents="agents"
        :teams="teams"
        :is-submitting="isSubmittingTicket"
        @close="closeTicketForm"
        @submit="submitTicket"
      />
    </woot-modal>

    <woot-modal v-model:show="showColumnForm" :on-close="closeColumnForm">
      <TicketColumnFormDialog
        :column="selectedColumn"
        @close="closeColumnForm"
        @submit="submitColumn"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteColumnConfirm"
      :on-close="closeDeleteColumnConfirm"
      :on-confirm="deleteColumnConfirmed"
      :title="$t('TICKET.COLUMN_DELETE.TITLE')"
      :message="$t('TICKET.COLUMN_DELETE.MESSAGE')"
      :message-value="selectedColumn ? ` ${selectedColumn.name}` : ''"
      :confirm-text="$t('TICKET.COLUMN_DELETE.CONFIRM')"
      :reject-text="$t('TICKET.COLUMN_DELETE.CANCEL')"
    />

    <woot-modal v-model:show="showBoardForm" :on-close="closeBoardForm">
      <TicketBoardFormDialog
        :board="editingBoard"
        @close="closeBoardForm"
        @submit="submitBoard"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteBoardConfirm"
      :on-close="closeDeleteBoardConfirm"
      :on-confirm="deleteBoardConfirmed"
      :title="$t('TICKET.BOARD_DELETE.TITLE')"
      :message="$t('TICKET.BOARD_DELETE.MESSAGE')"
      :message-value="editingBoard ? ` ${editingBoard.name}` : ''"
      :confirm-text="$t('TICKET.BOARD_DELETE.CONFIRM')"
      :reject-text="$t('TICKET.BOARD_DELETE.CANCEL')"
    />
  </div>
</template>
