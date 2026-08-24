<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import {
  addDays,
  addMonths,
  addWeeks,
  subDays,
  subMonths,
  subWeeks,
} from 'date-fns';
import AgendaHeader from 'dashboard/components-next/Agenda/AgendaView/AgendaHeader.vue';
import AgendaMonthView from 'dashboard/components-next/Agenda/AgendaView/AgendaMonthView.vue';
import AgendaWeekView from 'dashboard/components-next/Agenda/AgendaView/AgendaWeekView.vue';
import AgendaDayView from 'dashboard/components-next/Agenda/AgendaView/AgendaDayView.vue';
import CalendarEventFormDialog from 'dashboard/components-next/Agenda/CalendarEventFormDialog.vue';
import { visibleRangeFor } from 'dashboard/components-next/Agenda/helpers/agendaDateHelper';

const LAST_TEAM_STORAGE_KEY = 'agenda-last-team-id';

export default {
  components: {
    AgendaHeader,
    AgendaMonthView,
    AgendaWeekView,
    AgendaDayView,
    CalendarEventFormDialog,
  },
  data() {
    return {
      selectedTeamId: null,
      view: 'week',
      referenceDate: new Date(),
      showEventForm: false,
      selectedEvent: null,
      initialStart: null,
      showDeleteConfirm: false,
      selectedAgentIds: [],
    };
  },
  computed: {
    ...mapGetters({
      teams: 'teams/getTeams',
      eventsByTeam: 'calendarEvents/getEventsByTeam',
      teamMembersByTeam: 'teamMembers/getTeamMembers',
    }),
    agents() {
      return this.selectedTeamId ? this.teamMembersByTeam(this.selectedTeamId) : [];
    },
    events() {
      const teamEvents = this.selectedTeamId ? this.eventsByTeam(this.selectedTeamId) : [];
      if (!this.selectedAgentIds.length) return teamEvents;

      return teamEvents.filter(
        event =>
          this.selectedAgentIds.includes(event.created_by_id) ||
          (event.attendees || []).some(attendee => this.selectedAgentIds.includes(attendee.id))
      );
    },
  },
  watch: {
    selectedTeamId(teamId) {
      if (!teamId) return;
      window.localStorage.setItem(LAST_TEAM_STORAGE_KEY, teamId);
      this.selectedAgentIds = [];
      this.$store.dispatch('teamMembers/get', { teamId });
      this.loadEvents();
    },
    view() {
      this.loadEvents();
    },
    referenceDate() {
      this.loadEvents();
    },
  },
  mounted() {
    this.$store.dispatch('teams/get').then(() => this.pickInitialTeam());
  },
  methods: {
    pickInitialTeam() {
      const savedId = Number(window.localStorage.getItem(LAST_TEAM_STORAGE_KEY));
      const savedTeamExists = savedId && this.teams.some(team => team.id === savedId);
      this.selectedTeamId = savedTeamExists ? savedId : this.teams[0]?.id || null;
      if (this.selectedTeamId) this.loadEvents();
    },
    loadEvents() {
      if (!this.selectedTeamId) return;
      const { since, until } = visibleRangeFor(this.view, this.referenceDate);
      this.$store.dispatch('calendarEvents/get', {
        teamId: this.selectedTeamId,
        since: since.toISOString(),
        until: until.toISOString(),
      });
    },
    selectTeam(teamId) {
      this.selectedTeamId = teamId;
    },
    toggleAgentFilter(agentId) {
      this.selectedAgentIds = this.selectedAgentIds.includes(agentId)
        ? this.selectedAgentIds.filter(id => id !== agentId)
        : [...this.selectedAgentIds, agentId];
    },
    clearAgentFilter() {
      this.selectedAgentIds = [];
    },
    changeView(view) {
      this.view = view;
    },
    navigateToday() {
      this.referenceDate = new Date();
    },
    navigatePrevious() {
      if (this.view === 'month') this.referenceDate = subMonths(this.referenceDate, 1);
      else if (this.view === 'week') this.referenceDate = subWeeks(this.referenceDate, 1);
      else this.referenceDate = subDays(this.referenceDate, 1);
    },
    navigateNext() {
      if (this.view === 'month') this.referenceDate = addMonths(this.referenceDate, 1);
      else if (this.view === 'week') this.referenceDate = addWeeks(this.referenceDate, 1);
      else this.referenceDate = addDays(this.referenceDate, 1);
    },
    navigateDay(date) {
      this.referenceDate = date;
      this.view = 'day';
    },
    openCreateEvent({ start }) {
      this.selectedEvent = null;
      this.initialStart = start || null;
      this.showEventForm = true;
    },
    openEditEvent(event) {
      this.selectedEvent = event;
      this.initialStart = null;
      this.showEventForm = true;
    },
    closeEventForm() {
      this.showEventForm = false;
      this.selectedEvent = null;
      this.initialStart = null;
    },
    async submitEvent(payload) {
      try {
        if (this.selectedEvent) {
          await this.$store.dispatch('calendarEvents/update', {
            id: this.selectedEvent.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('calendarEvents/create', payload);
        }
        useAlert(this.$t('AGENDA.API.SUCCESS_MESSAGE'));
        this.closeEventForm();
      } catch (error) {
        useAlert(this.$t('AGENDA.API.ERROR_MESSAGE'));
      }
    },
    confirmDeleteEvent() {
      this.showEventForm = false;
      this.showDeleteConfirm = true;
    },
    async deleteEventConfirmed() {
      const event = this.selectedEvent;
      this.showDeleteConfirm = false;
      try {
        await this.$store.dispatch('calendarEvents/delete', {
          id: event.id,
          teamId: this.selectedTeamId,
        });
        useAlert(this.$t('AGENDA.API.DELETE_SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('AGENDA.API.DELETE_ERROR_MESSAGE'));
      } finally {
        this.selectedEvent = null;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full w-full min-h-0 min-w-0 p-3 gap-3 overflow-hidden">
    <AgendaHeader
      :teams="teams"
      :selected-team-id="selectedTeamId"
      :reference-date="referenceDate"
      :view="view"
      :agents="agents"
      :selected-agent-ids="selectedAgentIds"
      @select-team="selectTeam"
      @change-view="changeView"
      @navigate-previous="navigatePrevious"
      @navigate-next="navigateNext"
      @navigate-today="navigateToday"
      @create-event="openCreateEvent"
      @toggle-agent="toggleAgentFilter"
      @clear-agent-filter="clearAgentFilter"
    />

    <div
      v-if="!teams.length"
      class="flex flex-1 flex-col items-center justify-center gap-3 text-center"
    >
      <h2 class="text-base font-medium text-n-slate-12">{{ $t('AGENDA.EMPTY.TITLE') }}</h2>
      <p class="text-sm text-n-slate-11 max-w-sm">{{ $t('AGENDA.EMPTY.NO_TEAM_DESC') }}</p>
    </div>

    <template v-else>
      <AgendaMonthView
        v-if="view === 'month'"
        :reference-date="referenceDate"
        :events="events"
        class="flex-1 min-h-0"
        @navigate-day="navigateDay"
        @open-event="openEditEvent"
      />
      <AgendaWeekView
        v-else-if="view === 'week'"
        :reference-date="referenceDate"
        :events="events"
        class="flex-1 min-h-0"
        @create-event="openCreateEvent"
        @open-event="openEditEvent"
      />
      <AgendaDayView
        v-else
        :reference-date="referenceDate"
        :events="events"
        class="flex-1 min-h-0"
        @create-event="openCreateEvent"
        @open-event="openEditEvent"
      />
    </template>

    <woot-modal v-model:show="showEventForm" size="medium" :on-close="closeEventForm">
      <CalendarEventFormDialog
        :event="selectedEvent"
        :team-id="selectedTeamId"
        :initial-start="initialStart"
        @close="closeEventForm"
        @submit="submitEvent"
        @delete="confirmDeleteEvent"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirm"
      :on-close="() => (showDeleteConfirm = false)"
      :on-confirm="deleteEventConfirmed"
      :title="$t('AGENDA.DELETE.TITLE')"
      :message="$t('AGENDA.DELETE.MESSAGE')"
      :confirm-text="$t('AGENDA.DELETE.CONFIRM')"
      :reject-text="$t('AGENDA.DELETE.CANCEL')"
    />
  </div>
</template>
