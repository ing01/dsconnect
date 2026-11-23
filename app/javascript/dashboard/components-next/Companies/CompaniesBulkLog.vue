<script setup>
// "Log das alteracoes" da Gestao de clientes: o que cada alteracao em massa
// mudou, em que pe esta e, se algum cliente nao pode ser alterado, qual foi e
// por que - com o motivo escrito pelo servidor em portugues simples.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CompaniesAPI from 'dashboard/api/companies';
import { formatHistoryDate } from 'dashboard/components-next/message/helpers/contactHistoryHelper';

const POLL_INTERVAL = 3000;
const VISIBLE_FAILURES = 30;

const emit = defineEmits(['finished']);

const { t, locale } = useI18n();

const entries = ref([]);
const isLoaded = ref(false);
let timer = null;
let hadActive = false;

const hasActive = computed(() =>
  entries.value.some(entry => ['queued', 'running'].includes(entry.status))
);

const stopPolling = () => {
  if (timer) clearTimeout(timer);
  timer = null;
};

const load = async () => {
  stopPolling();
  try {
    const { data } = await CompaniesAPI.bulkUpdates();
    entries.value = data?.payload || [];
  } catch (error) {
    // O log e' so informativo: se nao carregar, a tela segue funcionando.
  } finally {
    isLoaded.value = true;
  }

  // Quando a ultima alteracao em andamento termina, avisa a tela para recarregar
  // a lista de clientes.
  if (hadActive && !hasActive.value) emit('finished');
  hadActive = hasActive.value;
  if (hasActive.value) timer = setTimeout(load, POLL_INTERVAL);
};

const statusKey = entry => {
  if (entry.status === 'completed') {
    return entry.failed_count > 0 ? 'COMPLETED_WITH_ERRORS' : 'COMPLETED';
  }
  return entry.status.toUpperCase();
};

const statusClass = entry => {
  if (entry.status === 'failed') return 'bg-n-ruby-3 text-n-ruby-11';
  if (entry.status === 'completed') {
    return entry.failed_count > 0
      ? 'bg-n-amber-3 text-n-amber-11'
      : 'bg-n-teal-3 text-n-teal-11';
  }
  return 'bg-n-blue-3 text-n-blue-11';
};

const isActive = entry => ['queued', 'running'].includes(entry.status);
const date = entry => formatHistoryDate(entry.created_at, locale.value);

onMounted(load);
onBeforeUnmount(stopPolling);

defineExpose({ reload: load });
</script>

<template>
  <details
    class="mx-6 mb-3 border rounded-xl border-n-weak bg-n-alpha-1"
    data-testid="bulk-log"
    :open="hasActive || entries.some(entry => entry.failed_count > 0)"
  >
    <summary class="px-4 py-3 text-sm font-medium cursor-pointer text-n-slate-12">
      {{ t('COMPANIES.MANAGEMENT.LOG.TITLE') }}
      <span v-if="hasActive" class="ml-2 text-xs font-normal text-n-blue-11">
        {{ t('COMPANIES.MANAGEMENT.LOG.STATUS.RUNNING') }}
      </span>
    </summary>

    <div class="flex flex-col gap-3 px-4 pb-4">
      <p
        v-if="isLoaded && !entries.length"
        class="m-0 text-sm text-n-slate-11"
        data-testid="bulk-log-empty"
      >
        {{ t('COMPANIES.MANAGEMENT.LOG.EMPTY') }}
      </p>

      <article
        v-for="entry in entries"
        :key="entry.id"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
        data-testid="bulk-log-entry"
      >
        <header class="flex flex-wrap items-center gap-x-3 gap-y-1">
          <span
            class="inline-flex px-2 py-0.5 text-xs font-semibold rounded-md"
            :class="statusClass(entry)"
          >
            {{ t(`COMPANIES.MANAGEMENT.LOG.STATUS.${statusKey(entry)}`) }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ date(entry) }}
            <template v-if="entry.user_name">
              · {{ t('COMPANIES.MANAGEMENT.LOG.BY', { name: entry.user_name }) }}
            </template>
          </span>
        </header>

        <ul v-if="entry.summary?.length" class="flex flex-wrap gap-1 p-0 m-0 list-none">
          <li
            v-for="line in entry.summary"
            :key="line"
            class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-12"
          >
            {{ line }}
          </li>
        </ul>

        <p v-if="isActive(entry)" class="m-0 text-sm text-n-slate-11" data-testid="bulk-log-progress">
          {{
            t('COMPANIES.MANAGEMENT.LOG.PROGRESS', {
              done: entry.processed_count,
              total: entry.total,
            })
          }}
        </p>
        <p v-else-if="entry.status === 'failed'" class="m-0 text-sm text-n-ruby-11">
          {{ t('COMPANIES.MANAGEMENT.LOG.FAILED_TITLE') }}
          <span v-if="entry.error_message">— {{ entry.error_message }}</span>
        </p>
        <p v-else class="m-0 text-sm text-n-slate-12">
          {{ t('COMPANIES.MANAGEMENT.LOG.RESULT', { count: entry.updated_count }, entry.updated_count) }}
          <template v-if="entry.failed_count > 0">
            ·
            <span class="text-n-amber-11">
              {{ t('COMPANIES.MANAGEMENT.LOG.ERRORS_COUNT', { count: entry.failed_count }, entry.failed_count) }}
            </span>
          </template>
        </p>

        <div v-if="entry.failures?.length" class="flex flex-col gap-1" data-testid="bulk-log-failures">
          <span class="text-xs font-medium text-n-slate-12">
            {{ t('COMPANIES.MANAGEMENT.LOG.FAILURES_TITLE') }}
          </span>
          <ul class="flex flex-col gap-1 p-0 m-0 list-none">
            <li
              v-for="failure in entry.failures.slice(0, VISIBLE_FAILURES)"
              :key="failure.id"
              class="text-sm text-n-slate-12"
            >
              <strong>{{ failure.name }}</strong>
              <span class="text-n-slate-11"> — {{ failure.error }}</span>
            </li>
          </ul>
          <span
            v-if="entry.failed_count > VISIBLE_FAILURES"
            class="text-xs text-n-slate-11"
          >
            {{ t('COMPANIES.MANAGEMENT.LOG.MORE', { count: entry.failed_count - VISIBLE_FAILURES }) }}
          </span>
          <p class="m-0 text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.LOG.FAILURES_HELP') }}
          </p>
        </div>
      </article>
    </div>
  </details>
</template>
