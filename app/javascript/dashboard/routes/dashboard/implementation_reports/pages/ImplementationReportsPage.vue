<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import ImplementationReportsAPI from 'dashboard/api/implementationReports';
import BarChart from 'shared/components/charts/BarChart.vue';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';
import ReportCard from '../components/ReportCard.vue';

const { t } = useI18n();
const store = useStore();

const teams = computed(() => store.getters['teams/getTeams'] || []);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const modules = computed(() => store.getters['projectModules/getModules'] || []);

const STAGES = [
  'pendente',
  'onboarding',
  'requisito',
  'em_andamento',
  'acompanhamento',
  'pos',
  'finalizado',
];

const selectedTeamId = ref(null);
const selectedImplementerId = ref(null);
const selectedModuleId = ref(null);
const selectedStage = ref(null);
const searchQuery = ref('');
const dateField = ref('start_date');
const sinceDate = ref('');
const untilDate = ref('');

const isLoading = ref(true);
const hoursSummary = ref({ total_hours: 0, by_category: {}, projects_count: 0 });
const monthly = ref([]);
const implementerReport = ref({ by_implementer: [], capacity: [] });
const moduleReport = ref([]);
const incidenceReport = ref([]);
const complexityReport = ref([]);

const filterParams = computed(() => {
  const params = {
    implementer_id: selectedImplementerId.value || undefined,
    project_module_id: selectedModuleId.value || undefined,
    team_id: selectedTeamId.value || undefined,
    stage: selectedStage.value || undefined,
    search: searchQuery.value || undefined,
    date_field: dateField.value || undefined,
  };
  if (sinceDate.value && untilDate.value) {
    params.since = String(Math.floor(new Date(`${sinceDate.value}T00:00:00`).getTime() / 1000));
    params.until = String(Math.floor(new Date(`${untilDate.value}T23:59:59`).getTime() / 1000));
  }
  return params;
});

const fetchAll = async () => {
  isLoading.value = true;
  try {
    const params = filterParams.value;
    const [hoursRes, monthlyRes, implRes, modRes, incRes, cplxRes] = await Promise.all([
      ImplementationReportsAPI.hoursSummary(params),
      ImplementationReportsAPI.monthly(params),
      ImplementationReportsAPI.byImplementer(params),
      ImplementationReportsAPI.byModule(params),
      ImplementationReportsAPI.incidence(params),
      ImplementationReportsAPI.complexity(params),
    ]);
    hoursSummary.value = hoursRes.data;
    monthly.value = monthlyRes.data;
    implementerReport.value = implRes.data;
    moduleReport.value = modRes.data;
    incidenceReport.value = incRes.data;
    complexityReport.value = cplxRes.data;
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  store.dispatch('projectModules/get');
  await fetchAll();
});

watch([selectedTeamId, selectedImplementerId, selectedModuleId, selectedStage, dateField, sinceDate, untilDate], fetchAll);

let searchTimeout = null;
watch(searchQuery, () => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(fetchAll, 300);
});

const clearPeriod = () => {
  sinceDate.value = '';
  untilDate.value = '';
};

const monthlyClientsChartData = computed(() => ({
  categories: monthly.value.map(row => row.month),
  series: [
    {
      id: 'clients_started',
      label: t('IMPLEMENTATION_REPORTS.MONTHLY.CLIENTS_SERIES'),
      color: 'rgb(var(--blue-9))',
      data: monthly.value.map(row => row.clients_started),
    },
  ],
}));

const monthlyHoursChartData = computed(() => ({
  categories: monthly.value.map(row => row.month),
  series: [
    {
      id: 'hours_logged',
      label: t('IMPLEMENTATION_REPORTS.MONTHLY.HOURS_SERIES'),
      color: 'rgb(var(--teal-9))',
      data: monthly.value.map(row => row.hours_logged),
    },
  ],
}));

// Classes completas e literais (não concatenadas) - o Tailwind só reconhece
// nomes de classe inteiros durante o build, uma string montada em pedaços
// (`bg-n-${cor}-3`) seria removida do CSS final.
const CLASSIFICATION_CLASSES = {
  normal: 'bg-n-teal-3 text-n-teal-11',
  atencao: 'bg-n-amber-3 text-n-amber-11',
  alto: 'bg-n-orange-3 text-n-orange-11',
  critico: 'bg-n-ruby-3 text-n-ruby-11',
};

const classificationClass = classification => CLASSIFICATION_CLASSES[classification] || 'bg-n-slate-3 text-n-slate-11';

const round1 = value => Math.round((value || 0) * 10) / 10;
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <ReportHeader :header-title="t('IMPLEMENTATION_REPORTS.HEADER')" />

    <!-- Filtros -->
    <div class="flex flex-wrap items-end gap-3 p-3 mb-4 rounded-xl border border-n-weak bg-n-solid-2">
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.SINCE') }}</label>
        <input v-model="sinceDate" type="date" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12" />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.UNTIL') }}</label>
        <input v-model="untilDate" type="date" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12" />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.DATE_FIELD') }}</label>
        <select v-model="dateField" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
          <option value="start_date">{{ t('IMPLEMENTATION_REPORTS.FILTERS.DATE_FIELD_START') }}</option>
          <option value="due_date">{{ t('IMPLEMENTATION_REPORTS.FILTERS.DATE_FIELD_DUE') }}</option>
          <option value="support_ends_on">{{ t('IMPLEMENTATION_REPORTS.FILTERS.DATE_FIELD_SUPPORT') }}</option>
        </select>
      </div>
      <button
        v-if="sinceDate || untilDate"
        type="button"
        class="h-8 px-2 text-xs text-n-slate-11 hover:underline"
        @click="clearPeriod"
      >
        {{ t('IMPLEMENTATION_REPORTS.FILTERS.CLEAR_PERIOD') }}
      </button>

      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.TEAM') }}</label>
        <select v-model="selectedTeamId" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
          <option :value="null">{{ t('IMPLEMENTATION_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">{{ team.name }}</option>
        </select>
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.IMPLEMENTER') }}</label>
        <select v-model="selectedImplementerId" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
          <option :value="null">{{ t('IMPLEMENTATION_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">{{ agent.name }}</option>
        </select>
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.MODULE') }}</label>
        <select v-model="selectedModuleId" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
          <option :value="null">{{ t('IMPLEMENTATION_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="mod in modules" :key="mod.id" :value="mod.id">{{ mod.name }}</option>
        </select>
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.STAGE') }}</label>
        <select v-model="selectedStage" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12">
          <option :value="null">{{ t('IMPLEMENTATION_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="stage in STAGES" :key="stage" :value="stage">
            {{ t(`PROJECTS.STAGES.${stage.toUpperCase()}`, stage) }}
          </option>
        </select>
      </div>
      <div class="flex flex-col gap-1 flex-1 min-w-[10rem]">
        <label class="text-[11px] font-medium text-n-slate-11">{{ t('IMPLEMENTATION_REPORTS.FILTERS.SEARCH') }}</label>
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="t('IMPLEMENTATION_REPORTS.FILTERS.SEARCH_PLACEHOLDER')"
          class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12"
        />
      </div>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.KPI.TOTAL_HOURS')" :is-loading="isLoading">
        <span class="text-2xl font-semibold text-n-slate-12">{{ round1(hoursSummary.total_hours) }}h</span>
      </ReportCard>
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.KPI.PROJECTS_COUNT')" :is-loading="isLoading">
        <span class="text-2xl font-semibold text-n-slate-12">{{ hoursSummary.projects_count }}</span>
      </ReportCard>
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.KPI.HOURS_IMPLANTACAO')" :is-loading="isLoading">
        <span class="text-2xl font-semibold text-n-slate-12">{{ round1(hoursSummary.by_category?.implantacao) }}h</span>
      </ReportCard>
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.KPI.HOURS_DESENVOLVIMENTO')" :is-loading="isLoading">
        <span class="text-2xl font-semibold text-n-slate-12">
          {{ round1((hoursSummary.by_category?.desenvolvimento || 0) + (hoursSummary.by_category?.dev_geral || 0)) }}h
        </span>
      </ReportCard>
    </div>

    <!-- Grafico mensal -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-4">
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.MONTHLY.CLIENTS_TITLE')" :is-loading="isLoading">
        <div class="h-56">
          <BarChart
            v-if="monthly.length"
            :data="monthlyClientsChartData"
            :aria-label="t('IMPLEMENTATION_REPORTS.MONTHLY.CLIENTS_TITLE')"
            :height="220"
          />
        </div>
      </ReportCard>
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.MONTHLY.HOURS_TITLE')" :is-loading="isLoading">
        <div class="h-56">
          <BarChart
            v-if="monthly.length"
            :data="monthlyHoursChartData"
            :aria-label="t('IMPLEMENTATION_REPORTS.MONTHLY.HOURS_TITLE')"
            :height="220"
          />
        </div>
      </ReportCard>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-4">
      <!-- Por modulo -->
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.MODULE.TITLE')" :is-loading="isLoading">
        <div class="flex flex-col gap-2">
          <div v-if="!moduleReport.length" class="text-xs text-n-slate-10">{{ t('IMPLEMENTATION_REPORTS.EMPTY') }}</div>
          <div
            v-for="row in moduleReport"
            :key="row.project_module_id || 'none'"
            class="flex items-center justify-between text-xs border-b border-n-weak last:border-0 py-1.5"
          >
            <span class="text-n-slate-12 font-medium truncate">
              {{ row.project_module_name || t('IMPLEMENTATION_REPORTS.MODULE.NO_MODULE') }}
            </span>
            <span class="text-n-slate-11 flex-shrink-0 ml-2">
              {{ row.projects_count }} ({{ row.percentage }}%) · {{ round1(row.total_hours) }}h
            </span>
          </div>
        </div>
      </ReportCard>

      <!-- Por implantador -->
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.IMPLEMENTER.TITLE')" :is-loading="isLoading">
        <div class="flex flex-col gap-2">
          <div v-if="!implementerReport.by_implementer.length" class="text-xs text-n-slate-10">{{ t('IMPLEMENTATION_REPORTS.EMPTY') }}</div>
          <div
            v-for="row in implementerReport.by_implementer"
            :key="row.implementer_id || 'none'"
            class="flex items-center justify-between text-xs border-b border-n-weak last:border-0 py-1.5"
          >
            <span class="text-n-slate-12 font-medium truncate">
              {{ row.implementer_name || t('IMPLEMENTATION_REPORTS.IMPLEMENTER.UNASSIGNED') }}
            </span>
            <span class="text-n-slate-11 flex-shrink-0 ml-2">
              {{ row.projects_count }} {{ t('IMPLEMENTATION_REPORTS.IMPLEMENTER.PROJECTS_SUFFIX') }} · {{ round1(row.total_hours) }}h
            </span>
          </div>
        </div>
      </ReportCard>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-4">
      <!-- Capacidade da equipe (period-independente) -->
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.CAPACITY.TITLE')" :is-loading="isLoading">
        <p class="text-[11px] text-n-slate-10 mb-2">{{ t('IMPLEMENTATION_REPORTS.CAPACITY.HINT') }}</p>
        <div class="flex flex-col gap-2">
          <div v-if="!implementerReport.capacity.length" class="text-xs text-n-slate-10">{{ t('IMPLEMENTATION_REPORTS.EMPTY') }}</div>
          <div
            v-for="row in implementerReport.capacity"
            :key="row.implementer_id || 'none'"
            class="flex items-center justify-between text-xs border-b border-n-weak last:border-0 py-1.5"
          >
            <span class="text-n-slate-12 font-medium truncate">
              {{ row.implementer_name || t('IMPLEMENTATION_REPORTS.IMPLEMENTER.UNASSIGNED') }}
            </span>
            <span class="text-n-slate-11 flex-shrink-0 ml-2">
              {{ row.projects_count }} {{ t('IMPLEMENTATION_REPORTS.IMPLEMENTER.PROJECTS_SUFFIX') }} · {{ round1(row.total_hours) }}h
            </span>
          </div>
        </div>
      </ReportCard>

      <!-- Score de complexidade -->
      <ReportCard :header="t('IMPLEMENTATION_REPORTS.COMPLEXITY.TITLE')" :is-loading="isLoading">
        <p class="text-[11px] text-n-slate-10 mb-2">{{ t('IMPLEMENTATION_REPORTS.COMPLEXITY.HINT') }}</p>
        <div class="flex flex-col gap-2 max-h-64 overflow-y-auto">
          <div v-if="!complexityReport.length" class="text-xs text-n-slate-10">{{ t('IMPLEMENTATION_REPORTS.EMPTY') }}</div>
          <div
            v-for="row in complexityReport"
            :key="row.project_id"
            class="flex items-center justify-between text-xs border-b border-n-weak last:border-0 py-1.5"
          >
            <span class="text-n-slate-12 font-medium truncate">{{ row.project_name }}</span>
            <span class="text-n-slate-11 flex-shrink-0 ml-2 font-semibold">{{ row.score }}</span>
          </div>
        </div>
      </ReportCard>
    </div>

    <!-- Incidencia no pos -->
    <ReportCard :header="t('IMPLEMENTATION_REPORTS.INCIDENCE.TITLE')" :is-loading="isLoading">
      <div v-if="!incidenceReport.length" class="text-xs text-n-slate-10">{{ t('IMPLEMENTATION_REPORTS.EMPTY') }}</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="text-left text-n-slate-10 border-b border-n-weak">
              <th class="py-1.5 font-medium">{{ t('IMPLEMENTATION_REPORTS.INCIDENCE.PROJECT') }}</th>
              <th class="py-1.5 font-medium">{{ t('IMPLEMENTATION_REPORTS.INCIDENCE.COMPANY') }}</th>
              <th class="py-1.5 font-medium text-right">{{ t('IMPLEMENTATION_REPORTS.INCIDENCE.TICKETS_COUNT') }}</th>
              <th class="py-1.5 font-medium">{{ t('IMPLEMENTATION_REPORTS.INCIDENCE.CLASSIFICATION') }}</th>
              <th class="py-1.5 font-medium">{{ t('IMPLEMENTATION_REPORTS.INCIDENCE.REINCIDENTE') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in incidenceReport" :key="row.project_id" class="border-b border-n-weak last:border-0">
              <td class="py-1.5 text-n-slate-12 font-medium">{{ row.project_name }}</td>
              <td class="py-1.5 text-n-slate-11">{{ row.company_name || '—' }}</td>
              <td class="py-1.5 text-right text-n-slate-12">{{ row.tickets_count }}</td>
              <td class="py-1.5">
                <span
                  class="px-1.5 py-0.5 rounded text-[11px] font-medium"
                  :class="classificationClass(row.classification)"
                >
                  {{ t(`IMPLEMENTATION_REPORTS.INCIDENCE.CLASSIFICATIONS.${row.classification.toUpperCase()}`) }}
                </span>
              </td>
              <td class="py-1.5 text-n-slate-11">{{ row.reincidente ? t('IMPLEMENTATION_REPORTS.INCIDENCE.YES') : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </ReportCard>
  </div>
</template>
