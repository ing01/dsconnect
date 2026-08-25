<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TicketListView from './TicketListView.vue';
import TicketCompanySelect from './TicketCompanySelect.vue';

const props = defineProps({
  teams: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

// Defaults are computed at open time (not hardcoded): first day of the
// current month through today, in the viewer's local timezone.
const toDateInputValue = date => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};
const today = new Date();
const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);

const draft = reactive({
  createdAfter: toDateInputValue(firstDayOfMonth),
  createdBefore: toDateInputValue(today),
  displayId: '',
  title: '',
  status: '',
  companyId: null,
  contactQuery: '',
  assigneeId: '',
  teamId: '',
  ticketColumnId: '',
});

// Only applied (and therefore searched) once the agent clicks "Buscar" -
// keeps every keystroke in a text field from firing a request.
const appliedFilters = ref({ ...draft });

const selectedTeamBoard = computed(() =>
  draft.teamId
    ? store.getters['ticketColumns/getBoard'](Number(draft.teamId))
    : null
);
const columnsForSelectedTeam = computed(
  () => selectedTeamBoard.value?.ticket_columns || []
);

watch(
  () => draft.teamId,
  teamId => {
    draft.ticketColumnId = '';
    if (teamId) store.dispatch('ticketColumns/fetchBoard', Number(teamId));
  }
);

const search = () => {
  appliedFilters.value = { ...draft };
};

const clearFilters = () => {
  Object.assign(draft, {
    displayId: '',
    title: '',
    status: '',
    companyId: null,
    contactQuery: '',
    assigneeId: '',
    teamId: '',
    ticketColumnId: '',
  });
  search();
};

onMounted(() => {
  store.dispatch('agents/get');
  search();
});
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="t('TICKET.SEARCH.TITLE')" />
    <div class="px-8 pb-4 flex flex-col gap-4">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.DATE_FROM')
          }}</span>
          <input
            v-model="draft.createdAfter"
            type="date"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.DATE_TO')
          }}</span>
          <input
            v-model="draft.createdBefore"
            type="date"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.NUMBER')
          }}</span>
          <input
            v-model="draft.displayId"
            type="number"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.STATUS')
          }}</span>
          <select
            v-model="draft.status"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          >
            <option value="">{{ t('TICKET.FILTERS.ALL_STATUSES') }}</option>
            <option value="open">{{ t('TICKET.STATUS.OPEN') }}</option>
            <option value="resolved">{{ t('TICKET.STATUS.RESOLVED') }}</option>
            <option value="closed">{{ t('TICKET.STATUS.CLOSED') }}</option>
          </select>
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.TITLE_FIELD')
          }}</span>
          <input
            v-model="draft.title"
            type="text"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          />
        </label>
        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.COMPANY')
          }}</span>
          <TicketCompanySelect v-model="draft.companyId" />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.CONTACT')
          }}</span>
          <input
            v-model="draft.contactQuery"
            type="text"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          />
        </label>
        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.ASSIGNEE')
          }}</span>
          <select
            v-model="draft.assigneeId"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          >
            <option value="">{{ t('TICKET.FORM.ASSIGNEE.NONE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.MESA')
          }}</span>
          <select
            v-model="draft.teamId"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm"
          >
            <option value="">{{ t('TICKET.SEARCH.ALL_MESAS') }}</option>
            <option v-for="team in props.teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">{{
            t('TICKET.SEARCH.ESTAGIO')
          }}</span>
          <select
            v-model="draft.ticketColumnId"
            :disabled="!draft.teamId"
            class="rounded-lg border border-n-strong bg-transparent px-2 py-1.5 text-sm disabled:opacity-50"
          >
            <option value="">{{ t('TICKET.SEARCH.ALL_ESTAGIOS') }}</option>
            <option
              v-for="column in columnsForSelectedTeam"
              :key="column.id"
              :value="column.id"
            >
              {{ column.name }}
            </option>
          </select>
        </label>
      </div>

      <div class="flex items-center justify-end gap-2">
        <NextButton
          ghost
          slate
          size="sm"
          :label="t('TICKET.FILTERS.CLEAR')"
          @click="clearFilters"
        />
        <NextButton
          size="sm"
          icon="i-lucide-search"
          :label="t('TICKET.SEARCH.SUBMIT')"
          @click="search"
        />
      </div>

      <TicketListView :filters="appliedFilters" class="h-96" />
    </div>
  </div>
</template>
