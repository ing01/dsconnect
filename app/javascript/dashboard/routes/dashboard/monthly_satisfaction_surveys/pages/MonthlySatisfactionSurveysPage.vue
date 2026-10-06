<script setup>
/**
 * Area INTERNA de consulta da Avaliacao Mensal (quem grava e' so o Portal do
 * Cliente - ver Api::V1::Client::MonthlySatisfactionSurveysController). Esta
 * tela e' so LEITURA: filtra por empresa/mes e mostra os agregados que o
 * servidor ja calcula (`meta.average_rating`/`meta.average_by_question`),
 * mais a lista individual de respostas - inclusive o comentario aberto, que
 * o pedido original deixa como algo a preparar para o futuro.
 *
 * O texto de cada pergunta e' lido do MESMO i18n do Portal do Cliente
 * (`CLIENT_AREA.MONTHLY_SURVEY.QUESTIONS.<chave>`) em vez de duplicado aqui -
 * as duas telas falam da mesma pergunta, reescrever a redacao num lugar so
 * mantem as duas em dia.
 */
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import MonthlySatisfactionSurveysAPI from 'dashboard/api/monthlySatisfactionSurveys';
import BarChart from 'shared/components/charts/BarChart.vue';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';
import ReportCard from '../../implementation_reports/components/ReportCard.vue';
import TicketCompanySelect from '../../tickets/components/TicketCompanySelect.vue';

const { t } = useI18n();

const companyId = ref(null);
const companyName = ref('');
const month = ref('');

const isLoading = ref(true);
const items = ref([]);
const meta = ref({ count: 0, average_rating: null, average_by_question: {} });
const expandedId = ref(null);

const filterParams = computed(() => ({
  company_id: companyId.value || undefined,
  reference_month: month.value ? `${month.value}-01` : undefined,
}));

const fetchSurveys = async () => {
  isLoading.value = true;
  try {
    const { data } = await MonthlySatisfactionSurveysAPI.get(
      filterParams.value
    );
    items.value = data.payload;
    meta.value = data.meta;
  } catch (error) {
    useAlert(t('MONTHLY_SATISFACTION_SURVEY_REPORT.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

onMounted(fetchSurveys);
watch([companyId, month], fetchSurveys);

const clearMonth = () => {
  month.value = '';
};

const onCompanySelected = company => {
  companyName.value = company?.name || '';
};

// O SERVIDOR ja manda as dez chaves, na ordem fixa do questionario (ver
// `index.json.jbuilder`) - sem precisar duplicar a lista aqui. So entra no
// grafico quem tem pelo menos uma resposta no recorte atual: o servidor manda
// `null` pra pergunta ainda sem nenhuma resposta, e uma barra em zero junto
// das outras confundiria "media baixa" com "ninguem respondeu isso".
const questionKeys = computed(() =>
  Object.keys(meta.value.average_by_question || {})
);

const questionAverages = computed(() =>
  questionKeys.value
    .map(chave => ({
      key: chave,
      label: t(`CLIENT_AREA.MONTHLY_SURVEY.QUESTIONS.${chave}`),
      value: meta.value.average_by_question?.[chave] ?? null,
    }))
    .filter(pergunta => pergunta.value !== null)
);

const lowestQuestion = computed(() => {
  if (!questionAverages.value.length) return null;
  return questionAverages.value.reduce((menor, atual) =>
    atual.value < menor.value ? atual : menor
  );
});

const chartData = computed(() => ({
  categories: questionAverages.value.map(p => p.label),
  series: [
    {
      id: 'average',
      label: t('MONTHLY_SATISFACTION_SURVEY_REPORT.CHART.SERIES_LABEL'),
      color: 'rgb(var(--blue-9))',
      data: questionAverages.value.map(p => Math.round(p.value * 10) / 10),
    },
  ],
}));

const round1 = value =>
  value === null || value === undefined ? null : Math.round(value * 10) / 10;

const toggleExpanded = id => {
  expandedId.value = expandedId.value === id ? null : id;
};

const answerFor = (survey, chave) =>
  survey.answers.find(resposta => resposta.question_key === chave)?.rating ??
  null;

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleDateString('pt-BR') : '';

const formatMonth = isoDate => {
  if (!isoDate) return '';
  const [ano, mes] = isoDate.split('-');
  return `${mes}/${ano}`;
};
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <ReportHeader
      :header-title="t('MONTHLY_SATISFACTION_SURVEY_REPORT.HEADER')"
      :header-description="
        t('MONTHLY_SATISFACTION_SURVEY_REPORT.HEADER_DESCRIPTION')
      "
    />

    <!-- Filtros -->
    <div
      class="flex flex-wrap items-end gap-3 p-3 mb-4 rounded-xl border border-n-weak bg-n-solid-2"
    >
      <div class="flex flex-col gap-1 w-full sm:w-56">
        <label class="text-[11px] font-medium text-n-slate-11">
          {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.FILTERS.COMPANY') }}
        </label>
        <TicketCompanySelect
          v-model="companyId"
          :initial-name="companyName"
          @select="onCompanySelected"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-[11px] font-medium text-n-slate-11">
          {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.FILTERS.MONTH') }}
        </label>
        <input
          v-model="month"
          type="month"
          class="h-10 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
        />
      </div>
      <button
        v-if="month"
        type="button"
        class="clear-month h-8 px-2 text-xs text-n-slate-11 hover:underline"
        @click="clearMonth"
      >
        {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.FILTERS.CLEAR_MONTH') }}
      </button>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
      <ReportCard
        :header="t('MONTHLY_SATISFACTION_SURVEY_REPORT.KPI.AVERAGE_RATING')"
        :is-loading="isLoading"
      >
        <span class="text-2xl font-semibold text-n-slate-12">
          {{
            round1(meta.average_rating) ??
            t('MONTHLY_SATISFACTION_SURVEY_REPORT.KPI.NO_RESPONSES')
          }}
        </span>
      </ReportCard>
      <ReportCard
        :header="t('MONTHLY_SATISFACTION_SURVEY_REPORT.KPI.RESPONSES_COUNT')"
        :is-loading="isLoading"
      >
        <span class="text-2xl font-semibold text-n-slate-12">
          {{ meta.count }}
        </span>
      </ReportCard>
      <ReportCard
        :header="t('MONTHLY_SATISFACTION_SURVEY_REPORT.KPI.LOWEST_QUESTION')"
        :is-loading="isLoading"
      >
        <template v-if="lowestQuestion">
          <p class="m-0 text-sm font-medium text-n-slate-12 line-clamp-2">
            {{ lowestQuestion.label }}
          </p>
          <span class="text-lg font-semibold text-n-ruby-11">
            {{ round1(lowestQuestion.value) }}
          </span>
        </template>
        <span v-else class="text-sm text-n-slate-10">
          {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.KPI.NO_RESPONSES') }}
        </span>
      </ReportCard>
    </div>

    <!-- Media por pergunta -->
    <ReportCard
      class="mb-4"
      :header="t('MONTHLY_SATISFACTION_SURVEY_REPORT.CHART.TITLE')"
      :is-loading="isLoading"
    >
      <div v-if="questionAverages.length" class="h-64 sm:h-72">
        <BarChart
          :data="chartData"
          :aria-label="t('MONTHLY_SATISFACTION_SURVEY_REPORT.CHART.TITLE')"
          :height="260"
        />
      </div>
      <div v-else class="text-xs text-n-slate-10">
        {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.EMPTY') }}
      </div>
    </ReportCard>

    <!-- Respostas -->
    <ReportCard
      :header="t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.TITLE')"
      :is-loading="isLoading"
    >
      <div v-if="!items.length" class="text-xs text-n-slate-10">
        {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.EMPTY') }}
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="text-left text-n-slate-10 border-b border-n-weak">
              <th class="py-1.5 font-medium">
                {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.COMPANY') }}
              </th>
              <th class="py-1.5 font-medium">
                {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.CONTACT') }}
              </th>
              <th class="py-1.5 font-medium">
                {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.MONTH') }}
              </th>
              <th class="py-1.5 font-medium text-right">
                {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.AVERAGE') }}
              </th>
              <th class="py-1.5 font-medium">
                {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.COMMENT') }}
              </th>
              <th class="py-1.5 font-medium">
                {{ t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.ANSWERED_AT') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="item in items" :key="item.id">
              <tr
                class="border-b border-n-weak last:border-0 cursor-pointer hover:bg-n-slate-2"
                @click="toggleExpanded(item.id)"
              >
                <td class="py-1.5 text-n-slate-12 font-medium">
                  {{
                    item.company_name ||
                    t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.NO_COMPANY')
                  }}
                </td>
                <td class="py-1.5 text-n-slate-11">
                  {{
                    item.contact_name ||
                    t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.NO_CONTACT')
                  }}
                </td>
                <td class="py-1.5 text-n-slate-11">
                  {{ formatMonth(item.reference_month) }}
                </td>
                <td class="py-1.5 text-right text-n-slate-12 font-semibold">
                  {{ round1(item.average_rating) }}
                </td>
                <td class="py-1.5 text-n-slate-11 truncate max-w-[16rem]">
                  {{
                    item.comment ||
                    t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.NO_COMMENT')
                  }}
                </td>
                <td class="py-1.5 text-n-slate-11">
                  {{ formatDate(item.created_at) }}
                </td>
              </tr>
              <tr v-if="expandedId === item.id" class="border-b border-n-weak">
                <td colspan="6" class="py-3 bg-n-slate-1">
                  <p class="text-[11px] font-medium text-n-slate-11 mb-2">
                    {{
                      t('MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.DETAILS_TITLE')
                    }}
                  </p>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                    <div
                      v-for="chave in questionKeys"
                      :key="chave"
                      class="flex items-center justify-between gap-2 text-xs"
                    >
                      <span class="text-n-slate-11 truncate">
                        {{ t(`CLIENT_AREA.MONTHLY_SURVEY.QUESTIONS.${chave}`) }}
                      </span>
                      <span class="text-n-slate-12 font-semibold flex-shrink-0">
                        {{ answerFor(item, chave) ?? '—' }}
                      </span>
                    </div>
                  </div>
                  <p
                    v-if="item.comment"
                    class="text-xs text-n-slate-12 mt-3 italic"
                  >
                    {{ item.comment }}
                  </p>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </ReportCard>
  </div>
</template>
