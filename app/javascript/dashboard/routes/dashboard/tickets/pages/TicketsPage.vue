<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketBoard from '../components/TicketBoard.vue';
import TicketCreateDialog from '../components/create/TicketCreateDialog.vue';
import TicketQuickActions from '../components/detail/actions/TicketQuickActions.vue';
import TicketAvatarFilterRow from '../components/TicketAvatarFilterRow.vue';
import TicketMesaSelector from '../components/TicketMesaSelector.vue';
import TicketSortMenu from '../components/TicketSortMenu.vue';
import { readSortPreference, writeSortPreference } from '../helpers/ticketSort';
import TicketDetailedSearchModal from '../components/TicketDetailedSearchModal.vue';

const LAST_TEAM_STORAGE_KEY = 'ticket-kanban-last-team-id';

export default {
  components: {
    NextButton,
    Spinner,
    NextInput,
    Icon,
    TicketBoard,
    TicketCreateDialog,
    TicketQuickActions,
    TicketAvatarFilterRow,
    TicketMesaSelector,
    TicketSortMenu,
    TicketDetailedSearchModal,
  },
  data() {
    return {
      showCreateForm: false,
      // Which ticket the card menu is acting on; the shared
      // dialogs load its detail payload from this.
      actionTicketId: null,
      showDetailedSearch: false,
      targetColumnId: null,
      selectedTeamId: null,
      selectedAgentIds: [],
      quickSearch: '',
      sort: null,
    };
  },
  computed: {
    ...mapGetters({
      teams: 'teams/getTeams',
      board: 'ticketColumns/getBoard',
      boardUIFlags: 'ticketColumns/getUIFlags',
      teamMembersByTeam: 'teamMembers/getTeamMembers',
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
    isLoading() {
      return this.boardUIFlags.isFetching && !this.selectedBoard;
    },
  },
  watch: {
    selectedTeamId(teamId) {
      if (!teamId) return;
      window.localStorage.setItem(LAST_TEAM_STORAGE_KEY, teamId);
      this.selectedAgentIds = [];
      this.quickSearch = '';
      // Sorting is remembered per Mesa, so it is reloaded rather than cleared.
      this.sort = readSortPreference(this.currentAccountId, teamId);
      this.loadMesa(teamId);
    },
  },
  mounted() {
    this.$store.dispatch('teams/get').then(() => this.pickInitialTeam());
  },
  methods: {
    // A brand-new account has no Mesa at all, which would leave the Kanban on a
    // dead-end empty state. Provisioning is server-side and idempotent, so this
    // only ever creates the default Mesa once.
    async bootstrapDefaultMesa() {
      try {
        await this.$store.dispatch('ticketColumns/ensureDefaultMesa');
        await this.$store.dispatch('teams/get');
      } catch (error) {
        // Falls through to the "no Mesa configured" empty state.
      }
    },
    async pickInitialTeam() {
      if (!this.teams.length) {
        await this.bootstrapDefaultMesa();
      }
      const savedId = Number(
        window.localStorage.getItem(LAST_TEAM_STORAGE_KEY)
      );
      const savedTeamExists =
        savedId && this.teams.some(team => team.id === savedId);
      this.selectedTeamId = savedTeamExists
        ? savedId
        : this.teams[0]?.id || null;
      if (this.selectedTeamId) {
        this.sort = readSortPreference(
          this.currentAccountId,
          this.selectedTeamId
        );
        this.loadMesa(this.selectedTeamId);
      }
    },
    loadMesa(teamId) {
      this.$store.dispatch('ticketColumns/fetchBoard', teamId);
      this.$store.dispatch('teamMembers/get', { teamId });
    },
    selectTeam(teamId) {
      this.selectedTeamId = Number(teamId);
    },
    // The filter row resolves add/remove/clear and hands over the full list.
    selectAgentFilter(agentIds) {
      this.selectedAgentIds = agentIds;
    },
    updateSort(sort) {
      this.sort = sort;
      writeSortPreference(this.currentAccountId, this.selectedTeamId, sort);
    },
    openTicketDetail(ticket) {
      this.$router.push(
        frontendURL(`accounts/${this.currentAccountId}/tickets/${ticket.id}`)
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
    // Reopening is the one transition a card still fires directly: it has no
    // requirements of its own, unlike closing.
    reopenTicket(ticket) {
      this.applyTransition('reopen', ticket);
    },
    // Every other action is the same flow the ticket page uses, so the card
    // hands it to the shared dialogs rather than repeating the wiring.
    onCardMenuAction({ action, ticket }) {
      if (action === 'reopen') {
        this.reopenTicket(ticket);
        return;
      }

      this.actionTicketId = ticket.id;
      // The dialogs mount once the detail payload has arrived.
      this.$nextTick(() => this.$refs.quickActions?.open(action));
    },
    // The board refetches so a ticket that was closed, transferred or merged
    // leaves the column it was in.
    onTicketChanged() {
      if (this.selectedTeamId) {
        this.$store.dispatch('ticketColumns/fetchBoard', this.selectedTeamId);
      }
    },
    // Opening a ticket goes through the shared creation form; the Mesa and the
    // Estagio are already known from the column that was clicked.
    openAddTicket(column) {
      this.targetColumnId = column.id;
      this.showCreateForm = true;
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
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 min-w-0 p-4 gap-4">
    <!-- `w-full min-w-0` is what keeps this page inside the shell: it is a flex
         item of Dashboard.vue's <main>, so without them its width is driven by
         the Kanban's max-content (every column added) and the header controls
         get pushed past the clipping edge of <main>. -->
    <header class="flex flex-col gap-3 w-full min-w-0 flex-shrink-0">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ $t('TICKET.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ $t('TICKET.DESCRIPTION') }}
        </p>
      </div>

      <!-- Mesa and Busca detalhada never shrink; the agent filter takes the
           slack and wraps to its own line first when space runs out. -->
      <div class="flex items-center gap-3 w-full min-w-0 flex-wrap">
        <TicketMesaSelector
          v-if="teams.length"
          :teams="teams"
          :selected-team-id="selectedTeamId"
          @select="selectTeam"
        />

        <TicketAvatarFilterRow
          v-if="selectedTeamId"
          :agents="mesaAgents"
          :selected-agent-ids="selectedAgentIds"
          class="flex-1 min-w-0 order-last sm:order-none"
          @select="selectAgentFilter"
        />

        <!-- Quick search filters the loaded board on the spot; the detailed
             search next to it stays the modal that queries the API. -->
        <NextInput
          v-if="selectedTeamId"
          v-model="quickSearch"
          type="search"
          size="sm"
          class="group w-56 min-w-0 flex-shrink-0 ltr:ml-auto rtl:mr-auto [&>input]:ltr:!pl-8 [&>input]:rtl:!pr-8 [&>input]:!rounded-[0.625rem]"
          :placeholder="$t('TICKET.SEARCH.QUICK_PLACEHOLDER')"
          :aria-label="$t('TICKET.SEARCH.QUICK_PLACEHOLDER')"
        >
          <template #prefix>
            <Icon
              icon="i-lucide-search"
              class="absolute top-1/2 -translate-y-1/2 text-n-slate-11 group-focus-within:text-n-brand size-3.5 ltr:left-2.5 rtl:right-2.5"
            />
          </template>
        </NextInput>

        <TicketSortMenu
          v-if="selectedTeamId"
          :sort="sort"
          @update="updateSort"
        />

        <NextButton
          icon="i-lucide-search"
          faded
          slate
          size="sm"
          class="flex-shrink-0"
          :class="selectedTeamId ? '' : 'ltr:ml-auto rtl:mr-auto'"
          :label="$t('TICKET.SEARCH.BUTTON')"
          @click="showDetailedSearch = true"
        />
      </div>
    </header>

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
      :account-id="currentAccountId"
      :team-id="selectedTeamId"
      :agents="mesaAgents"
      :filters="{ assigneeIds: selectedAgentIds, query: quickSearch }"
      :sort="sort"
      class="flex-1 min-h-0 min-w-0"
      @add-ticket="openAddTicket"
      @open-ticket="openTicketDetail"
      @move-ticket="moveTicket"
      @menu-action="onCardMenuAction"
    />

    <!-- The ticket actions, shared with the detail page: same store actions,
         same permissions, same backend validations. -->
    <TicketQuickActions
      ref="quickActions"
      :ticket-id="actionTicketId"
      @changed="onTicketChanged"
    />

    <!-- Creation uses the shared form; the edit dialog below still serves the
         card's "Editar" action. -->
    <woot-modal
      v-model:show="showCreateForm"
      :on-close="closeCreateForm"
      size="large"
    >
      <TicketCreateDialog
        allow-create-another
        :context="{ teamId: selectedTeamId, ticketColumnId: targetColumnId }"
        @close="closeCreateForm"
        @created="onTicketCreated"
      />
    </woot-modal>

    <woot-modal
      v-model:show="showDetailedSearch"
      :on-close="() => (showDetailedSearch = false)"
      size="medium"
    >
      <TicketDetailedSearchModal :teams="teams" />
    </woot-modal>
  </div>
</template>
