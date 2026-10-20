<script setup>
/**
 * O relatorio de SLA de tickets: cumprimento por agente e por Cliente -
 * combinado ("Tudo") ou por tipo de relogio (atendimento/estagio/solucao),
 * como pedido ("deve ser possivel ver junto ou separado").
 *
 * O servidor ja manda os 4 recortes de cada linha (3 tipos + o combinado) -
 * o seletor de tipo aqui so troca QUAL recorte aparece, sem pedir de novo ao
 * servidor. Isso e o que deixa alternar junto/separado instantaneo.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import TicketSlaReportsAPI from 'dashboard/api/ticketSlaReports';
import TicketCompanySelect from '../../tickets/components/TicketCompanySelect.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const teams = useMapGetter('teams/getTeams');

const KINDS = ['all', 'response', 'stage', 'resolution'];

const filters = ref({ from: '', to: '', teamId: '', companyId: null });
const companyName = ref('');
const selectedKind = ref('all');
const report = ref(null);
const isLoading = ref(false);

const kindLabel = kind => t(`TICKET_SLA_REPORTS.KIND.${kind.toUpperCase()}`);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await TicketSlaReportsAPI.fetch({
      from: filters.value.from || undefined,
      to: filters.value.to || undefined,
      team_id: filters.value.teamId || undefined,
      company_id: filters.value.companyId || undefined,
    });
    report.value = data;
  } catch (error) {
    useAlert(t('TICKET_SLA_REPORTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const clear = () => {
  filters.value = { from: '', to: '', teamId: '', companyId: null };
  companyName.value = '';
  load();
};

// Os totais do recorte escolhido: "Tudo" e' `totals` (os 3 tipos somados,
// sempre do periodo/filtros inteiros); um tipo especifico vem de `by_kind`.
const displayTotals = computed(() => {
  if (!report.value) return null;
  if (selectedKind.value === 'all') return report.value.totals;

  return report.value.by_kind.find(row => row.kind === selectedKind.value);
});

const agentRows = computed(() =>
  (report.value?.by_user || []).filter(row => row.kind === selectedKind.value)
);

const companyRows = computed(() =>
  (report.value?.by_company || []).filter(
    row => row.kind === selectedKind.value
  )
);

const hours = value =>
  t('TICKET_SLA_REPORTS.HOURS', {
    hours: Math.round((value || 0) * 100) / 100,
  });

onMounted(() => {
  store.dispatch('teams/get');
  load();
});
</script>

<template>
  <div class="flex flex-col gap-4 p-6 overflow-auto">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('TICKET_SLA_REPORTS.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('TICKET_SLA_REPORTS.DESC') }}
      </p>
    </div>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_SLA_REPORTS.FILTERS.FROM') }}
        </span>
        <input v-model="filters.from" type="date" class="w-full mb-0 text-sm" />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_SLA_REPORTS.FILTERS.TO') }}
        </span>
        <input v-model="filters.to" type="date" class="w-full mb-0 text-sm" />
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_SLA_REPORTS.FILTERS.TEAM') }}
        </span>
        <select v-model="filters.teamId" class="w-full mb-0 text-sm">
          <option value="">{{ t('TICKET_SLA_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TICKET_SLA_REPORTS.FILTERS.COMPANY') }}
        </span>
        <TicketCompanySelect
          v-model="filters.companyId"
          :initial-name="companyName"
          @select="company => (companyName = company?.name || '')"
        />
      </label>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <Button
        type="button"
        :label="t('TICKET_SLA_REPORTS.FILTERS.APPLY')"
        :is-loading="isLoading"
        @click="load"
      />
      <Button
        faded
        slate
        type="button"
        :label="t('TICKET_SLA_REPORTS.FILTERS.CLEAR')"
        @click="clear"
      />

      <!-- O pedido: ver junto ou separado - troca so' o que ja chegou, sem
           recarregar. -->
      <div class="flex items-center gap-1 p-1 ml-auto rounded-lg bg-n-alpha-1">
        <button
          v-for="kind in KINDS"
          :key="kind"
          type="button"
          class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors"
          :class="
            selectedKind === kind
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="selectedKind = kind"
        >
          {{ kindLabel(kind) }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="flex items-center gap-2 py-6">
      <Spinner />
      <span class="text-sm text-n-slate-11">
        {{ t('TICKET_SLA_REPORTS.LOADING') }}
      </span>
    </div>

    <template v-else-if="displayTotals">
      <div
        class="grid grid-cols-2 gap-3 px-4 py-3 border rounded-lg sm:grid-cols-4 xl:grid-cols-7 border-n-weak bg-n-alpha-black2"
      >
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.CLOCKS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ displayTotals.clocks }}
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.HIT') }}
          </span>
          <span class="text-lg font-medium text-n-teal-11">
            {{ displayTotals.hit }}
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.MISSED') }}
          </span>
          <span class="text-lg font-medium text-n-ruby-11">
            {{ displayTotals.missed }}
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.ACTIVE') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ displayTotals.active }}
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.HIT_RATE') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ displayTotals.hit_rate }}%
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.ACTUAL_HOURS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ hours(displayTotals.actual_hours) }}
          </span>
        </div>
        <div class="flex flex-col">
          <span class="text-xs text-n-slate-10">
            {{ t('TICKET_SLA_REPORTS.METRICS.OVERRUN_HOURS') }}
          </span>
          <span class="text-lg font-medium text-n-ruby-11">
            {{ hours(displayTotals.overrun_hours) }}
          </span>
        </div>
      </div>

      <section class="flex flex-col gap-2">
        <h2 class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET_SLA_REPORTS.BY_AGENT') }}
        </h2>
        <p v-if="!agentRows.length" class="text-sm text-n-slate-10">
          {{ t('TICKET_SLA_REPORTS.NO_ENTRIES') }}
        </p>
        <div v-else class="overflow-x-auto border rounded-lg border-n-weak">
          <table class="w-full text-sm">
            <thead class="bg-n-alpha-1">
              <tr class="text-xs text-left text-n-slate-10">
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.NAME') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.CLOCKS') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.HIT_RATE') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.ACTUAL_HOURS') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.OVERRUN_HOURS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in agentRows"
                :key="row.user_id"
                class="border-t border-n-weak"
              >
                <td class="px-3 py-2 font-medium truncate text-n-slate-12">
                  {{ row.user_name || t('TICKET_SLA_REPORTS.UNASSIGNED') }}
                </td>
                <td class="px-3 py-2 text-n-slate-11">{{ row.clocks }}</td>
                <td class="px-3 py-2 text-n-slate-11">{{ row.hit_rate }}%</td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ hours(row.actual_hours) }}
                </td>
                <td class="px-3 py-2 text-n-ruby-11">
                  {{ hours(row.overrun_hours) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- O cruzamento que a analise de margem por Cliente pede: mesmo recorte,
           agrupado por Empresa em vez de por agente. -->
      <section class="flex flex-col gap-2">
        <h2 class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET_SLA_REPORTS.BY_COMPANY') }}
        </h2>
        <p v-if="!companyRows.length" class="text-sm text-n-slate-10">
          {{ t('TICKET_SLA_REPORTS.NO_ENTRIES') }}
        </p>
        <div v-else class="overflow-x-auto border rounded-lg border-n-weak">
          <table class="w-full text-sm">
            <thead class="bg-n-alpha-1">
              <tr class="text-xs text-left text-n-slate-10">
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.NAME') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.CLOCKS') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.HIT_RATE') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.ACTUAL_HOURS') }}
                </th>
                <th class="px-3 py-2 font-medium">
                  {{ t('TICKET_SLA_REPORTS.METRICS.OVERRUN_HOURS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in companyRows"
                :key="row.company_id"
                class="border-t border-n-weak"
              >
                <td class="px-3 py-2 font-medium truncate text-n-slate-12">
                  {{ row.company_name || t('TICKET_SLA_REPORTS.NO_COMPANY') }}
                </td>
                <td class="px-3 py-2 text-n-slate-11">{{ row.clocks }}</td>
                <td class="px-3 py-2 text-n-slate-11">{{ row.hit_rate }}%</td>
                <td class="px-3 py-2 text-n-slate-11">
                  {{ hours(row.actual_hours) }}
                </td>
                <td class="px-3 py-2 text-n-ruby-11">
                  {{ hours(row.overrun_hours) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </div>
</template>
