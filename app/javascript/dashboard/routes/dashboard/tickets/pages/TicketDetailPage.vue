<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import TicketComments from '../components/TicketComments.vue';
import TicketActivityTimeline from '../components/TicketActivityTimeline.vue';

const PRIORITY_COLORS = {
  low: 'slate',
  medium: 'blue',
  high: 'amber',
  urgent: 'ruby',
};
const STATUS_COLORS = { open: 'slate', resolved: 'green', closed: 'violet' };

export default {
  components: {
    NextButton,
    Spinner,
    Icon,
    WootLabel,
    TicketComments,
    TicketActivityTimeline,
  },
  data() {
    return {
      isTransitioning: false,
      isUpdating: false,
      activeTab: 'activity',
      editingAssignment: false,
      draftAssigneeId: '',
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
    }),
    ticketId() {
      return this.$route.params.ticketId;
    },
    ticket() {
      return this.$store.getters['tickets/getTicket'](this.ticketId);
    },
    isLoading() {
      return (
        this.$store.getters['tickets/getUIFlags'].isFetchingItem && !this.ticket
      );
    },
    ticketColumn() {
      if (!this.ticket) return null;
      const board = this.$store.getters['ticketColumns/getBoard'](
        this.ticket.team_id
      );
      const column = (board?.ticket_columns || []).find(
        col => col.id === this.ticket.ticket_column_id
      );
      if (!column) return null;
      return { ...column, boardName: this.teamName };
    },
    assigneeName() {
      const agent = this.agents.find(a => a.id === this.ticket?.assignee_id);
      return agent?.name || this.ticket?.assignee_name || this.$t('TICKET.FORM.ASSIGNEE.NONE');
    },
    teamName() {
      const team = this.teams.find(t => t.id === this.ticket?.team_id);
      return team?.name || this.ticket?.team_name || this.$t('TICKET.FORM.TEAM.NONE');
    },
    statusColor() {
      return STATUS_COLORS[this.ticket?.status] || 'slate';
    },
    priorityColor() {
      return PRIORITY_COLORS[this.ticket?.priority] || 'slate';
    },
    conversationIds() {
      return this.ticket?.conversation_ids || [];
    },
  },
  watch: {
    ticketId: {
      immediate: true,
      handler() {
        this.loadTicket();
      },
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
  },
  methods: {
    async loadTicket() {
      try {
        const ticket = await this.$store.dispatch(
          'tickets/fetchTicket',
          this.ticketId
        );
        if (ticket?.team_id) {
          this.$store.dispatch('ticketColumns/fetchBoard', ticket.team_id);
        }
      } catch (error) {
        useAlert(this.$t('TICKET.API.ERROR_MESSAGE'));
      }
    },
    goBack() {
      this.$router.push(
        frontendURL(`accounts/${this.$route.params.accountId}/tickets`)
      );
    },
    openConversation(conversationId) {
      this.$router.push(
        frontendURL(
          `accounts/${this.$route.params.accountId}/conversations/${conversationId}`
        )
      );
    },
    async transition(action) {
      this.isTransitioning = true;
      try {
        await this.$store.dispatch(`tickets/${action}Ticket`, this.ticketId);
        this.$store.dispatch('ticketColumns/applyRealtimeTicket', this.ticket);
        this.$store.dispatch('tickets/fetchActivities', this.ticketId);
        useAlert(this.$t(`TICKET.DETAIL.${action.toUpperCase()}_SUCCESS`));
      } catch (error) {
        useAlert(this.$t('TICKET.API.ERROR_MESSAGE'));
      } finally {
        this.isTransitioning = false;
      }
    },
    startEditingAssignment() {
      this.draftAssigneeId = this.ticket?.assignee_id || '';
      this.editingAssignment = true;
    },
    async saveAssignment() {
      this.isUpdating = true;
      try {
        const updated = await this.$store.dispatch('tickets/updateTicket', {
          id: this.ticketId,
          assignee_id: this.draftAssigneeId || null,
        });
        this.$store.dispatch('ticketColumns/applyRealtimeTicket', updated);
        this.$store.dispatch('tickets/fetchActivities', this.ticketId);
        this.editingAssignment = false;
        useAlert(this.$t('TICKET.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('TICKET.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdating = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0 p-4 gap-4 overflow-auto">
    <button
      type="button"
      class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12 w-fit"
      @click="goBack"
    >
      <Icon icon="i-lucide-arrow-left" class="size-3.5" />
      {{ $t('TICKET.DETAIL.BACK') }}
    </button>

    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <Spinner />
    </div>

    <template v-else-if="ticket">
      <div class="flex items-start justify-between gap-4 flex-wrap">
        <div class="flex flex-col gap-1 min-w-0">
          <span class="text-xs text-n-slate-10">#{{ ticket.display_id }}</span>
          <h1 class="text-xl font-medium text-n-slate-12">
            {{ ticket.title }}
          </h1>
          <div class="flex items-center gap-2 flex-wrap">
            <WootLabel
              :label="$t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
              :color="statusColor"
            />
            <WootLabel
              v-if="ticket.priority"
              :label="
                $t(`TICKET.FORM.PRIORITY.${ticket.priority.toUpperCase()}`)
              "
              :color="priorityColor"
            />
            <span v-if="ticketColumn" class="text-xs text-n-slate-10">
              {{ ticketColumn.boardName }} · {{ ticketColumn.name }}
            </span>
          </div>
        </div>

        <div class="flex items-center gap-2 flex-shrink-0">
          <NextButton
            v-if="ticket.status === 'open'"
            size="sm"
            :is-loading="isTransitioning"
            :label="$t('TICKET.DETAIL.RESOLVE')"
            @click="transition('resolve')"
          />
          <NextButton
            v-if="ticket.status === 'resolved'"
            size="sm"
            :is-loading="isTransitioning"
            :label="$t('TICKET.DETAIL.CLOSE')"
            @click="transition('close')"
          />
          <NextButton
            v-if="ticket.status !== 'open'"
            size="sm"
            faded
            slate
            :is-loading="isTransitioning"
            :label="$t('TICKET.DETAIL.REOPEN')"
            @click="transition('reopen')"
          />
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 flex-1 min-h-0">
        <div class="lg:col-span-2 flex flex-col gap-4 min-h-0 overflow-auto">
          <section class="rounded-xl border border-n-weak p-4">
            <h2 class="text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('TICKET.FORM.DESCRIPTION.LABEL') }}
            </h2>
            <p class="text-sm text-n-slate-11 whitespace-pre-wrap">
              {{ ticket.description || $t('TICKET.DETAIL.NO_DESCRIPTION') }}
            </p>
          </section>

          <section class="rounded-xl border border-n-weak p-4">
            <h2 class="text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('TICKET.DETAIL.LINKED_CONVERSATIONS') }}
            </h2>
            <p v-if="!conversationIds.length" class="text-sm text-n-slate-11">
              {{ $t('TICKET.DETAIL.NO_CONVERSATIONS') }}
            </p>
            <div v-else class="flex flex-col gap-2">
              <button
                v-for="conversationId in conversationIds"
                :key="conversationId"
                type="button"
                class="flex items-center justify-between gap-2 px-3 py-2 rounded-lg border border-n-weak hover:bg-n-slate-2 text-left"
                @click="openConversation(conversationId)"
              >
                <span class="text-sm text-n-slate-12">
                  {{
                    $t('TICKET.DETAIL.CONVERSATION_LABEL', {
                      id: conversationId,
                    })
                  }}
                </span>
                <Icon
                  icon="i-lucide-square-arrow-out-up-right"
                  class="size-3.5 text-n-slate-10"
                />
              </button>
            </div>
          </section>

          <section class="rounded-xl border border-n-weak p-4">
            <div class="flex gap-4 border-b border-n-weak mb-3">
              <button
                type="button"
                class="pb-2 text-sm border-b-2"
                :class="
                  activeTab === 'activity'
                    ? 'border-n-brand text-n-slate-12 font-medium'
                    : 'border-transparent text-n-slate-11'
                "
                @click="activeTab = 'activity'"
              >
                {{ $t('TICKET.DETAIL.TAB_ACTIVITY') }}
              </button>
              <button
                type="button"
                class="pb-2 text-sm border-b-2"
                :class="
                  activeTab === 'comments'
                    ? 'border-n-brand text-n-slate-12 font-medium'
                    : 'border-transparent text-n-slate-11'
                "
                @click="activeTab = 'comments'"
              >
                {{ $t('TICKET.DETAIL.TAB_COMMENTS') }}
              </button>
            </div>
            <TicketActivityTimeline
              v-if="activeTab === 'activity'"
              :ticket-id="ticketId"
            />
            <TicketComments v-else :ticket-id="ticketId" />
          </section>
        </div>

        <aside class="flex flex-col gap-3">
          <section
            class="rounded-xl border border-n-weak p-4 flex flex-col gap-3"
          >
            <div class="flex items-center justify-between">
              <h2 class="text-sm font-medium text-n-slate-12">
                {{ $t('TICKET.DETAIL.ASSIGNMENT') }}
              </h2>
              <button
                v-if="!editingAssignment"
                type="button"
                class="text-xs text-n-blue-11 hover:underline"
                @click="startEditingAssignment"
              >
                {{ $t('TICKET.DETAIL.TRANSFER') }}
              </button>
            </div>

            <template v-if="!editingAssignment">
              <div class="flex flex-col gap-1">
                <span class="text-xs text-n-slate-10">{{
                  $t('TICKET.FORM.ASSIGNEE.LABEL')
                }}</span>
                <span class="text-sm text-n-slate-12">{{ assigneeName }}</span>
              </div>
              <div class="flex flex-col gap-1">
                <span class="text-xs text-n-slate-10">{{
                  $t('TICKET.FORM.TEAM.LABEL')
                }}</span>
                <span class="text-sm text-n-slate-12">{{ teamName }}</span>
              </div>
            </template>
            <template v-else>
              <label class="flex flex-col gap-1">
                <span class="text-xs text-n-slate-10">{{
                  $t('TICKET.FORM.ASSIGNEE.LABEL')
                }}</span>
                <select
                  v-model="draftAssigneeId"
                  class="w-full rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
                >
                  <option value="">
                    {{ $t('TICKET.FORM.ASSIGNEE.NONE') }}
                  </option>
                  <option
                    v-for="agent in agents"
                    :key="agent.id"
                    :value="agent.id"
                  >
                    {{ agent.name }}
                  </option>
                </select>
              </label>
              <p class="text-xs text-n-slate-10">
                {{ $t('TICKET.DETAIL.TEAM_TRANSFER_HINT') }}
              </p>
              <div class="flex justify-end gap-2">
                <NextButton
                  faded
                  slate
                  size="sm"
                  :label="$t('TICKET.FORM.CANCEL')"
                  @click="editingAssignment = false"
                />
                <NextButton
                  size="sm"
                  :is-loading="isUpdating"
                  :label="$t('TICKET.FORM.UPDATE')"
                  @click="saveAssignment"
                />
              </div>
            </template>
          </section>
        </aside>
      </div>
    </template>
  </div>
</template>
