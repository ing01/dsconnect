<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import TicketReportsAPI from 'dashboard/api/ticketReports';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import TicketCompanySelect from '../../tickets/components/TicketCompanySelect.vue';

const { t } = useI18n();
const store = useStore();

const agents = useMapGetter('agents/getAgents');
const catalogs = useMapGetter('serviceCatalogs/getCatalogs');

const STATUS_COLORS = {
  open: 'blue',
  resolved: 'teal',
  closed: 'slate',
  cancelled: 'ruby',
};

const emptyFilters = () => ({
  companyId: null,
  companyName: '',
  status: '',
  assigneeId: '',
  serviceCatalogId: '',
  openedFrom: '',
  openedTo: '',
  closedFrom: '',
  closedTo: '',
});

const filters = ref(emptyFilters());
const rows = ref([]);
const isLoading = ref(false);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await TicketReportsAPI.fetch({
      company_id: filters.value.companyId || undefined,
      status: filters.value.status || undefined,
      assignee_id: filters.value.assigneeId || undefined,
      service_catalog_id: filters.value.serviceCatalogId || undefined,
      opened_from: filters.value.openedFrom || undefined,
      opened_to: filters.value.openedTo || undefined,
      closed_from: filters.value.closedFrom || undefined,
      closed_to: filters.value.closedTo || undefined,
    });
    rows.value = data;
  } catch (error) {
    useAlert(t('TICKET_REPORTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const clear = () => {
  filters.value = emptyFilters();
  load();
};

const formatDate = value =>
  value ? new Date(value).toLocaleDateString() : '—';

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('serviceCatalogs/fetch');
  load();
});
</script>

<template>
  <div class="flex flex-col gap-4 p-6 overflow-auto">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('TICKET_REPORTS.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('TICKET_REPORTS.DESC') }}
      </p>
    </div>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3 xl:grid-cols-5 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.COMPANY') }}
        </span>
        <TicketCompanySelect
          v-model="filters.companyId"
          :initial-name="filters.companyName"
          @select="
            company => {
              filters.companyName = company?.name || '';
            }
          "
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.STATUS') }}
        </span>
        <select v-model="filters.status" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_REPORTS.FILTERS.ALL') }}</option>
          <option value="open">{{ t('TICKET.STATUS.OPEN') }}</option>
          <option value="resolved">{{ t('TICKET.STATUS.RESOLVED') }}</option>
          <option value="closed">{{ t('TICKET.STATUS.CLOSED') }}</option>
          <option value="cancelled">{{ t('TICKET.STATUS.CANCELLED') }}</option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.ASSIGNEE') }}
        </span>
        <select v-model="filters.assigneeId" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.CATALOG') }}
        </span>
        <select v-model="filters.serviceCatalogId" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_REPORTS.FILTERS.ALL') }}</option>
          <option
            v-for="catalog in catalogs"
            :key="catalog.id"
            :value="catalog.id"
          >
            {{ catalog.name }}
          </option>
        </select>
      </label>
    </div>

    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.OPENED_FROM') }}
        </span>
        <input
          v-model="filters.openedFrom"
          type="date"
          class="w-full mb-0 text-sm"
        />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.OPENED_TO') }}
        </span>
        <input
          v-model="filters.openedTo"
          type="date"
          class="w-full mb-0 text-sm"
        />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.CLOSED_FROM') }}
        </span>
        <input
          v-model="filters.closedFrom"
          type="date"
          class="w-full mb-0 text-sm"
        />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_REPORTS.FILTERS.CLOSED_TO') }}
        </span>
        <input
          v-model="filters.closedTo"
          type="date"
          class="w-full mb-0 text-sm"
        />
      </label>
    </div>

    <div class="flex gap-2">
      <Button
        type="button"
        :label="t('TICKET_REPORTS.FILTERS.APPLY')"
        :is-loading="isLoading"
        @click="load"
      />
      <Button
        faded
        slate
        type="button"
        :label="t('TICKET_REPORTS.FILTERS.CLEAR')"
        @click="clear"
      />
    </div>

    <div v-if="isLoading" class="flex items-center gap-2 py-6">
      <Spinner />
      <span class="text-sm text-n-slate-11">
        {{ t('TICKET_REPORTS.LOADING') }}
      </span>
    </div>

    <div v-else class="overflow-x-auto border rounded-lg border-n-weak">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-n-weak bg-n-alpha-black2">
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.TICKET') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.COMPANY') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.CATALOG') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.TEAM') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.ASSIGNEE') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.CATEGORY') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.STATUS') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.OPENED_AT') }}
            </th>
            <th class="px-3 py-2 text-left whitespace-nowrap">
              {{ t('TICKET_REPORTS.TABLE.CLOSED_AT') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!rows.length">
            <td colspan="9" class="px-3 py-6 text-center text-n-slate-10">
              {{ t('TICKET_REPORTS.EMPTY') }}
            </td>
          </tr>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-b border-n-weak last:border-0"
          >
            <td class="px-3 py-2 whitespace-nowrap text-n-slate-12">
              #{{ row.display_id }}
            </td>
            <td class="px-3 py-2 min-w-0 truncate text-n-slate-12">
              {{ row.company_name || '—' }}
            </td>
            <td class="px-3 py-2 min-w-0 truncate text-n-slate-11">
              {{ row.service_catalog_name || '—' }}
            </td>
            <td class="px-3 py-2 min-w-0 truncate text-n-slate-11">
              {{ row.team_name || '—' }}
            </td>
            <td class="px-3 py-2 min-w-0 truncate text-n-slate-11">
              {{ row.assignee_name || '—' }}
            </td>
            <td class="px-3 py-2 min-w-0 truncate text-n-slate-11">
              {{ row.category_name || '—' }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              <WootLabel
                :label="t(`TICKET.STATUS.${row.status.toUpperCase()}`)"
                :color="STATUS_COLORS[row.status] || 'slate'"
                compact
              />
            </td>
            <td class="px-3 py-2 whitespace-nowrap text-n-slate-11">
              {{ formatDate(row.created_at) }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap text-n-slate-11">
              {{ formatDate(row.closed_at) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
