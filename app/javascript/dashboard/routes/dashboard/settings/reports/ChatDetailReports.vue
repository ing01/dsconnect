<script setup>
/**
 * Relatório "Chat detalhado": uma linha por conversa (quem iniciou, quando foi
 * assumida, espera, duração, responsável, ticket, avaliação...) e, acima, o resumo
 * do período. O mesmo conteúdo sai em Excel, em duas abas (Chat Detalhado e Resumo).
 *
 * Os rótulos das colunas e dos indicadores vêm do servidor, que é quem define o que o
 * relatório contém - assim a tela e o Excel nunca divergem.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { downloadBlob } from 'dashboard/helper/downloadHelper';
import ChatDetailReportsAPI from 'dashboard/api/chatDetailReports';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const inboxes = useMapGetter('inboxes/getInboxes');

const STATUSES = ['open', 'pending', 'snoozed', 'resolved'];

const pad = value => String(value).padStart(2, '0');
const isoDate = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;

// Abre no mês corrente: o período que o relatório costuma responder.
const defaultFilters = () => {
  const today = new Date();
  return {
    from: isoDate(new Date(today.getFullYear(), today.getMonth(), 1)),
    to: isoDate(today),
    assigneeId: '',
    teamId: '',
    inboxId: '',
    status: '',
  };
};

const filters = ref(defaultFilters());
const rows = ref([]);
const columns = ref([]);
const summaryColumns = ref([]);
const summary = ref(null);
const meta = ref({ count: 0, page: 1, per_page: 25 });
const isLoading = ref(false);
const isExporting = ref(false);

const params = () => ({
  from: filters.value.from || undefined,
  to: filters.value.to || undefined,
  assignee_id: filters.value.assigneeId || undefined,
  team_id: filters.value.teamId || undefined,
  inbox_id: filters.value.inboxId || undefined,
  status: filters.value.status || undefined,
});

const pageCount = computed(() =>
  Math.max(1, Math.ceil(meta.value.count / meta.value.per_page))
);

const errorMessage = error =>
  error?.response?.data?.error || t('CHAT_DETAIL_REPORTS.ERROR');

const load = async (page = 1) => {
  isLoading.value = true;
  try {
    const { data } = await ChatDetailReportsAPI.fetch({ ...params(), page });
    rows.value = data.payload;
    columns.value = data.columns;
    summaryColumns.value = data.summary_columns;
    summary.value = data.summary;
    meta.value = data.meta;
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isLoading.value = false;
  }
};

const clear = () => {
  filters.value = defaultFilters();
  load();
};

// Nem todo ambiente traz `Blob.text()`; o FileReader é o segundo caminho. A mensagem
// real do servidor (ex.: período grande demais) chega como blob, porque o pedido
// esperava um arquivo.
const blobToText = blob =>
  typeof blob.text === 'function'
    ? blob.text()
    : new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsText(blob);
      });

const exportError = async error => {
  const data = error?.response?.data;
  if (data instanceof Blob) {
    try {
      const parsed = JSON.parse(await blobToText(data));
      if (parsed?.error) return parsed.error;
    } catch (parseError) {
      // cai no aviso genérico
    }
  }
  return t('CHAT_DETAIL_REPORTS.EXPORT_ERROR');
};

const exportXlsx = async () => {
  if (isExporting.value) return;

  isExporting.value = true;
  try {
    const response = await ChatDetailReportsAPI.exportXlsx(params());
    downloadBlob(
      response.data,
      'chat-detalhado.xlsx',
      response.headers?.['content-disposition']
    );
  } catch (error) {
    useAlert(await exportError(error));
  } finally {
    isExporting.value = false;
  }
};

const cell = (row, key) => {
  const value = row[key];
  return value === null || value === undefined || value === '' ? '—' : value;
};

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('teams/get');
  store.dispatch('inboxes/get');
  load();
});
</script>

<template>
  <div class="flex flex-col gap-4 p-6 overflow-auto min-w-0">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('CHAT_DETAIL_REPORTS.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.DESC') }}
        </p>
      </div>
      <Button
        type="button"
        icon="i-lucide-sheet"
        :label="t('CHAT_DETAIL_REPORTS.EXPORT')"
        :is-loading="isExporting"
        :disabled="isExporting || meta.count === 0"
        data-testid="chat-export"
        @click="exportXlsx"
      />
    </div>

    <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.FILTERS.FROM') }}
        </span>
        <input
          v-model="filters.from"
          type="date"
          class="w-full mb-0 text-sm"
          data-testid="chat-filter-from"
        />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.FILTERS.TO') }}
        </span>
        <input
          v-model="filters.to"
          type="date"
          class="w-full mb-0 text-sm"
          data-testid="chat-filter-to"
        />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.FILTERS.ASSIGNEE') }}
        </span>
        <select v-model="filters.assigneeId" class="w-full mb-0 text-sm">
          <option value="">{{ t('CHAT_DETAIL_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.FILTERS.TEAM') }}
        </span>
        <select v-model="filters.teamId" class="w-full mb-0 text-sm">
          <option value="">{{ t('CHAT_DETAIL_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.FILTERS.INBOX') }}
        </span>
        <select v-model="filters.inboxId" class="w-full mb-0 text-sm">
          <option value="">{{ t('CHAT_DETAIL_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CHAT_DETAIL_REPORTS.FILTERS.STATUS') }}
        </span>
        <select v-model="filters.status" class="w-full mb-0 text-sm">
          <option value="">{{ t('CHAT_DETAIL_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="status in STATUSES" :key="status" :value="status">
            {{ t(`CHAT_DETAIL_REPORTS.STATUS.${status.toUpperCase()}`) }}
          </option>
        </select>
      </label>
    </div>

    <div class="flex gap-2">
      <Button
        type="button"
        :label="t('CHAT_DETAIL_REPORTS.FILTERS.APPLY')"
        :is-loading="isLoading"
        data-testid="chat-apply"
        @click="load(1)"
      />
      <Button
        faded
        slate
        type="button"
        :label="t('CHAT_DETAIL_REPORTS.FILTERS.CLEAR')"
        @click="clear"
      />
    </div>

    <!-- Os 8 indicadores do período (a aba "Resumo" do Excel). -->
    <div
      v-if="summary"
      class="grid grid-cols-2 gap-3 sm:grid-cols-4 min-w-0"
      data-testid="chat-summary"
    >
      <div
        v-for="item in summaryColumns"
        :key="item.key"
        class="flex flex-col gap-1 p-3 border rounded-xl border-n-weak bg-n-solid-1 min-w-0"
      >
        <span class="text-xs text-n-slate-11 truncate">{{ item.label }}</span>
        <span
          class="text-lg font-medium text-n-slate-12"
          :data-testid="`chat-summary-${item.key}`"
        >
          {{ summary[item.key] }}
        </span>
      </div>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center p-8">
      <Spinner />
    </div>

    <p
      v-else-if="!rows.length"
      class="p-6 m-0 text-sm text-center border border-dashed rounded-xl border-n-weak text-n-slate-11"
      data-testid="chat-empty"
    >
      {{ t('CHAT_DETAIL_REPORTS.EMPTY') }}
    </p>

    <div v-else class="overflow-x-auto border rounded-xl border-n-weak">
      <table class="w-full text-sm" data-testid="chat-table">
        <thead>
          <tr class="text-left bg-n-alpha-1 text-n-slate-11">
            <th
              v-for="column in columns"
              :key="column.key"
              class="px-3 py-2 font-medium whitespace-nowrap"
            >
              {{ column.label }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-t border-n-weak text-n-slate-12"
          >
            <td
              v-for="column in columns"
              :key="column.key"
              class="px-3 py-2 whitespace-nowrap"
            >
              {{ cell(row, column.key) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      v-if="meta.count > meta.per_page"
      class="flex items-center justify-between gap-3 text-sm text-n-slate-11"
    >
      <span>
        {{
          t('CHAT_DETAIL_REPORTS.PAGE_OF', {
            page: meta.page,
            pages: pageCount,
            count: meta.count,
          })
        }}
      </span>
      <div class="flex gap-2">
        <Button
          faded
          slate
          sm
          type="button"
          icon="i-lucide-chevron-left"
          :disabled="meta.page <= 1 || isLoading"
          :label="t('CHAT_DETAIL_REPORTS.PREVIOUS')"
          data-testid="chat-prev"
          @click="load(meta.page - 1)"
        />
        <Button
          faded
          slate
          sm
          type="button"
          icon="i-lucide-chevron-right"
          :disabled="meta.page >= pageCount || isLoading"
          :label="t('CHAT_DETAIL_REPORTS.NEXT')"
          data-testid="chat-next"
          @click="load(meta.page + 1)"
        />
      </div>
    </div>
  </div>
</template>
