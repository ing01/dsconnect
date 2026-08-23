<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketBoard from '../components/TicketBoard.vue';
import TicketFormDialog from '../components/TicketFormDialog.vue';
import TicketColumnFormDialog from '../components/TicketColumnFormDialog.vue';
import TicketAvatarFilterRow from '../components/TicketAvatarFilterRow.vue';
import TicketDetailedSearchModal from '../components/TicketDetailedSearchModal.vue';

const LAST_TEAM_STORAGE_KEY = 'ticket-kanban-last-team-id';

export default {
  components: {
    NextButton,
    Spinner,
    TicketBoard,
    TicketFormDialog,
    TicketColumnFormDialog,
    TicketAvatarFilterRow,
    TicketDetailedSearchModal,
  },
  data() {
    return {
      showTicketForm: false,
      showColumnForm: false,
      showDeleteColumnConfirm: false,
      showDetailedSearch: false,
      isSubmittingTicket: false,
      selectedTicket: null,
      selectedColumn: null,
      targetColumnId: null,
      selectedTeamId: null,
      selectedAgentId: null,
    };
  },
  computed: {
    ...mapGetters({
      teams: 'teams/getTeams',
      board: 'ticketColumns/getBoard',
      boardUIFlags: 'ticketColumns/getUIFlags',
      teamMembersByTeam: 'teamMembers/getTeamMembers',
      currentRole: 'getCurrentRole',
      currentAccountId: 'getCurrentAccountId',
    }),
    selectedBoard() {
      return this.selectedTeamId ? this.board(this.selectedTeamId) : null;
    },
    mesaAgents() {
      return this.selectedTeamId
        ? this.teamMembersByTeam(this.selectedTeamId)
        : [];
    },
    isAdmin() {
      return this.currentRole === 'administrator';
    },
    isLoading() {
      return this.boardUIFlags.isFetching && !this.selectedBoard;
    },
  },
  watch: {
    selectedTeamId(teamId) {
      if (!teamId) return;
      window.localStorage.setItem(LAST_TEAM_STORAGE_KEY, teamId);
      this.selectedAgentId = null;
      this.loadMesa(teamId);
    },
  },
  mounted() {
    this.$store.dispatch('teams/get').then(() => this.pickInitialTeam());
  },
  methods: {
    pickInitialTeam() {
      const savedId = Number(
        window.localStorage.getItem(LAST_TEAM_STORAGE_KEY)
      );
      const savedTeamExists =
        savedId && this.teams.some(team => team.id === savedId);
      this.selectedTeamId = savedTeamExists
        ? savedId
        : this.teams[0]?.id || null;
      if (this.selectedTeamId) this.loadMesa(this.selectedTeamId);
    },
    loadMesa(teamId) {
      this.$store.dispatch('ticketColumns/fetchBoard', teamId);
      this.$store.dispatch('teamMembers/get', { teamId });
    },
    selectTeam(teamId) {
      this.selectedTeamId = Number(teamId);
    },
    selectAgentFilter(agentId) {
      this.selectedAgentId = this.selectedAgentId === agentId ? null : agentId;
    },
    openTicketDetail(ticket) {
      this.$router.push(
        frontendURL(`accounts/${this.currentAccountId}/tickets/${ticket.id}`)
      );
    },
    openConversationFromTicket(ticket) {
      const conversationId = ticket.conversation_ids?.[0];
      if (!conversationId) return;
      this.$router.push(
        frontendURL(
          `accounts/${this.currentAccountId}/conversations/${conversationId}`
        )
      );
    },
    async applyTransition(action, ticket) {
      try {
        const updated = await this.$store.dispatch(
          `tickets/${action}Ticket`,
          ticket.id
        );
        this.$store.dispatch('ticketColumns/applyRealtimeTicket', updated);
      } catch (error) {
        useAlert(this.$t('TICKET.API.ERROR_MESSAGE'));
      }
    },
    resolveTicket(ticket) {
      this.applyTransition('resolve', ticket);
    },
    reopenTicket(ticket) {
      this.applyTransition('reopen', ticket);
    },
    closeTicket(ticket) {
      this.applyTransition('close', ticket);
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
          await this.$store.dispatch('ticketColumns/updateTicket', {
            teamId: this.selectedTeamId,
            id: this.selectedTicket.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('ticketColumns/createTicket', {
            teamId: this.selectedTeamId,
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
          await this.$store.dispatch('ticketColumns/updateColumn', {
            teamId: this.selectedTeamId,
            columnId: this.selectedColumn.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('ticketColumns/createColumn', {
            teamId: this.selectedTeamId,
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
        await this.$store.dispatch('ticketColumns/deleteColumn', {
          teamId: this.selectedTeamId,
          columnId: column.id,
        });
        useAlert(this.$t('TICKET.API.COLUMN_DELETE_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('TICKET.API.COLUMN_DELETE_ERROR'));
      }
    },
    async moveTicket({ ticketId, ticketColumnId, position }) {
      try {
        await this.$store.dispatch('ticketColumns/moveTicket', {
          teamId: this.selectedTeamId,
          id: ticketId,
          ticketColumnId,
          position,
        });
      } catch (error) {
        useAlert(this.$t('TICKET.API.MOVE_ERROR'));
      }
    },
    async reorderColumns(columnIds) {
      await this.$store.dispatch('ticketColumns/reorderColumns', {
        teamId: this.selectedTeamId,
        columnIds,
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0 p-4 gap-4">
    <div class="flex items-start justify-between gap-4 flex-shrink-0 flex-wrap">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ $t('TICKET.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ $t('TICKET.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex items-center gap-2 flex-shrink-0">
        <select
          v-if="teams.length"
          :value="selectedTeamId"
          class="h-8 rounded-lg border border-n-strong bg-transparent px-2 text-sm text-n-slate-12"
          @change="selectTeam($event.target.value)"
        >
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
        <NextButton
          icon="i-lucide-search"
          faded
          slate
          size="sm"
          :label="$t('TICKET.SEARCH.BUTTON')"
          @click="showDetailedSearch = true"
        />
      </div>
    </div>

    <TicketAvatarFilterRow
      v-if="selectedTeamId"
      :agents="mesaAgents"
      :selected-agent-id="selectedAgentId"
      @select="selectAgentFilter"
    />

    <div
      v-if="!teams.length"
      class="flex flex-1 flex-col items-center justify-center gap-3 text-center"
    >
      <h2 class="text-base font-medium text-n-slate-12">
        {{ $t('TICKET.EMPTY.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-11 max-w-sm">
        {{ $t('TICKET.EMPTY.NO_MESA_DESC') }}
      </p>
    </div>

    <div
      v-else-if="isLoading"
      class="flex items-center justify-center gap-2 flex-1 text-n-slate-11"
    >
      <Spinner />
      <span class="text-sm">{{ $t('TICKET.LOADING') }}</span>
    </div>

    <TicketBoard
      v-else-if="selectedBoard"
      :board="selectedBoard"
      :agents="mesaAgents"
      :is-admin="isAdmin"
      :filters="{ assigneeId: selectedAgentId }"
      class="flex-1 min-h-0"
      @add-ticket="openAddTicket"
      @open-ticket="openTicketDetail"
      @edit-ticket="openEditTicket"
      @add-column="openAddColumn"
      @edit-column="openEditColumn"
      @delete-column="confirmDeleteColumn"
      @move-ticket="moveTicket"
      @reorder-columns="reorderColumns"
      @open-conversation="openConversationFromTicket"
      @resolve-ticket="resolveTicket"
      @reopen-ticket="reopenTicket"
      @close-ticket="closeTicket"
    />

    <woot-modal v-model:show="showTicketForm" :on-close="closeTicketForm">
      <TicketFormDialog
        :ticket="selectedTicket"
        :agents="mesaAgents"
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

    <woot-modal
      v-model:show="showDetailedSearch"
      :on-close="() => (showDetailedSearch = false)"
      size="medium"
    >
      <TicketDetailedSearchModal :teams="teams" />
    </woot-modal>
  </div>
</template>
