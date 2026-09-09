<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { toSearchParams } from '../helpers/ticketSearchParams';
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

// Cada cabecalho e a chave que o servidor entende (Tickets::SearchOrdering).
// A ordenacao vai para o servidor porque a lista e paginada la: ordenar so as
// linhas carregadas mostraria o menor valor DESTA pagina, e nao do resultado.
const COLUMNS = [
  { key: 'display_id', label: 'ID' },
  { key: 'created_at', label: 'CREATED_AT' },
  { key: 'title', label: 'TITLE' },
  { key: 'company', label: 'COMPANY' },
  { key: 'contact', label: 'REQUESTER' },
  { key: 'status', label: 'STATUS' },
  { key: 'team', label: 'MESA' },
  { key: 'ticket_column', label: 'ESTAGIO' },
  { key: 'assignee', label: 'ASSIGNEE' },
];

const sortBy = ref('');
const sortOrder = ref('asc');

const requestParams = computed(() => ({
  page: listMeta.value.currentPage || 1,
  per_page: PER_PAGE,
  ...toSearchParams(props.filters),
  // Sem coluna escolhida o parametro nao vai, e o servidor mantem a ordem de
  // sempre - mais recentes primeiro.
  sort_by: sortBy.value || undefined,
  sort_order: sortBy.value ? sortOrder.value : undefined,
}));

const loadTickets = (page = 1) => {
  store.dispatch('tickets/fetchTickets', { ...requestParams.value, page });
};

// Primeiro clique ordena crescente; no mesmo cabecalho, inverte. Trocar de
// coluna recomeca crescente e volta para a primeira pagina, porque a ordem
// mudou e a pagina atual deixou de significar o mesmo conjunto.
const sortByColumn = key => {
  if (sortBy.value === key) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortBy.value = key;
    sortOrder.value = 'asc';
  }
  loadTickets(1);
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
            <th
              v-for="column in COLUMNS"
              :key="column.key"
              class="px-3 py-2 font-medium"
              :aria-sort="
                sortBy === column.key
                  ? sortOrder === 'asc'
                    ? 'ascending'
                    : 'descending'
                  : 'none'
              "
            >
              <button
                type="button"
                class="flex items-center gap-1 font-medium transition-colors hover:text-n-slate-12"
                :class="sortBy === column.key ? 'text-n-slate-12' : ''"
                @click="sortByColumn(column.key)"
              >
                {{ t(`TICKET.LIST.COLUMNS.${column.label}`) }}
                <!-- A seta so aparece na coluna que esta ordenando, para nao
                     sugerir que todas estao ativas ao mesmo tempo. -->
                <span
                  v-if="sortBy === column.key"
                  :class="
                    sortOrder === 'asc'
                      ? 'i-lucide-arrow-up'
                      : 'i-lucide-arrow-down'
                  "
                  class="size-3"
                />
              </button>
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
