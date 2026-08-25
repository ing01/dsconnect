<script setup>
import { computed, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

// `filters` is the flat, camelCase state owned by TicketDetailedSearchModal
// (the "Busca detalhada" panel) - this component only turns it into
// backend query params and renders the resulting page of results.
const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
});
import { statusColor } from '../helpers/ticketLabels';

const PER_PAGE = 25;

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const currentAccountId = useMapGetter('getCurrentAccountId');

const tickets = computed(() => store.getters['tickets/getTicketsList']);
const listMeta = computed(() => store.getters['tickets/getListMeta']);
const uiFlags = computed(() => store.getters['tickets/getUIFlags']);
const isLoading = computed(() => uiFlags.value.isFetchingList);

const requestParams = computed(() => ({
  page: listMeta.value.currentPage || 1,
  per_page: PER_PAGE,
  status: props.filters.status || undefined,
  team_id: props.filters.teamId || undefined,
  ticket_column_id: props.filters.ticketColumnId || undefined,
  assignee_id: props.filters.assigneeId || undefined,
  display_id: props.filters.displayId || undefined,
  title: props.filters.title || undefined,
  contact_query: props.filters.contactQuery || undefined,
  company_id: props.filters.companyId || undefined,
  created_after: props.filters.createdAfter || undefined,
  created_before: props.filters.createdBefore || undefined,
}));

const loadTickets = (page = 1) => {
  store.dispatch('tickets/fetchTickets', { ...requestParams.value, page });
};

const onPageChange = page => loadTickets(page);

const openTicket = ticket => {
  router.push(
    frontendURL(`accounts/${currentAccountId.value}/tickets/${ticket.id}`)
  );
};

watch(
  () => props.filters,
  () => loadTickets(1),
  { deep: true }
);

onMounted(() => loadTickets(1));
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-2">
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <div
      v-else-if="!tickets.length"
      class="flex items-center justify-center flex-1"
    >
      <p class="text-sm text-n-slate-11">{{ t('TICKET.LIST.EMPTY') }}</p>
    </div>

    <div
      v-else
      class="flex-1 min-h-0 overflow-auto rounded-xl border border-n-weak"
    >
      <table class="w-full text-sm">
        <thead class="sticky top-0 bg-n-solid-1 border-b border-n-weak">
          <tr class="text-left text-xs text-n-slate-10">
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.ID') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.CREATED_AT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.TITLE') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.COMPANY') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.REQUESTER') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.STATUS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.MESA') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.ESTAGIO') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('TICKET.LIST.COLUMNS.ASSIGNEE') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="ticket in tickets"
            :key="ticket.id"
            class="border-b border-n-weak last:border-b-0 cursor-pointer hover:bg-n-slate-2"
            @click="openTicket(ticket)"
          >
            <td class="px-3 py-2 text-n-slate-10 whitespace-nowrap">
              #{{ ticket.display_id }}
            </td>
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ new Date(ticket.created_at * 1000).toLocaleDateString() }}
            </td>
            <td class="px-3 py-2 text-n-slate-12 font-medium max-w-xs truncate">
              {{ ticket.title }}
            </td>
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ ticket.company_name || '—' }}
            </td>
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ ticket.requester_name || '—' }}
            </td>
            <td class="px-3 py-2">
              <WootLabel
                :label="t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
                :color="statusColor(ticket.status)"
                compact
              />
            </td>
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ ticket.team_name || '—' }}
            </td>
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ ticket.ticket_column_name || '—' }}
            </td>
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ ticket.assignee_name || '—' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <PaginationFooter
      v-if="listMeta.count > PER_PAGE"
      :current-page="listMeta.currentPage"
      :total-items="listMeta.count"
      :items-per-page="PER_PAGE"
      @update:current-page="onPageChange"
    />
  </div>
</template>
