<script setup>
/**
 * Indicadores do Painel Comercial - mesmas visoes do painel standalone antigo
 * (cartoes de KPI, tendencia mensal, ranking de vendedor/produto/canal).
 * O grafico de tendencia sempre olha todo o periodo, igual ao painel antigo;
 * so os KPIs e os rankings respeitam o filtro escolhido.
 */
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CrmDashboardAPI from 'dashboard/api/crmDashboard';
import ReportHeader from '../../settings/reports/components/ReportHeader.vue';

const { t } = useI18n();

const isLoading = ref(true);
const period = ref('all');
const periods = ref({ years: [], months: [] });
const kpis = ref(null);
const trend = ref([]);
const sellerRanking = ref([]);
const productRanking = ref([]);
const channelRanking = ref([]);

const formatCurrency = value => `R$ ${Number(value || 0).toFixed(2)}`;

const maxTrendValue = computed(() =>
  Math.max(
    1,
    ...trend.value.map(entry =>
      Math.max(entry.implementation_value, entry.monthly_value)
    )
  )
);

const maxSellerMonthly = computed(() =>
  Math.max(1, ...sellerRanking.value.map(seller => seller.monthly_value))
);

const fetchDashboard = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmDashboardAPI.get({ period: period.value });
    periods.value = data.periods;
    kpis.value = data.kpis;
    trend.value = data.trend;
    sellerRanking.value = data.seller_ranking;
    productRanking.value = data.product_ranking;
    channelRanking.value = data.channel_ranking;
  } catch {
    useAlert(t('CRM.DASHBOARD.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch(period, fetchDashboard);
onMounted(fetchDashboard);
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <ReportHeader :header-title="t('CRM.DASHBOARD.HEADER')" />
    <p class="mb-4 text-sm text-n-slate-11">{{ t('CRM.DASHBOARD.DESCRIPTION') }}</p>

    <div class="flex items-center gap-3 mb-4">
      <label class="text-xs font-medium text-n-slate-11">{{ t('CRM.DASHBOARD.PERIOD') }}</label>
      <select
        v-model="period"
        class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12"
      >
        <option value="all">{{ t('CRM.DASHBOARD.ALL_PERIODS') }}</option>
        <option v-for="year in periods.years" :key="`y-${year}`" :value="`year:${year}`">
          {{ year }}
        </option>
        <option v-for="month in periods.months" :key="`m-${month}`" :value="`month:${month}`">
          {{ month }}
        </option>
      </select>
    </div>

    <div v-if="kpis" class="grid grid-cols-2 md:grid-cols-5 gap-3 mb-6">
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.DASHBOARD.KPIS.IMPLEMENTATION') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">{{ formatCurrency(kpis.total_implementation) }}</div>
      </div>
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.DASHBOARD.KPIS.MONTHLY') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">{{ formatCurrency(kpis.total_monthly) }}</div>
      </div>
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.DASHBOARD.KPIS.SALES_COUNT') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">{{ kpis.sales_count }}</div>
      </div>
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.DASHBOARD.KPIS.UNIQUE_CLIENTS') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">{{ kpis.unique_clients }}</div>
      </div>
      <div class="p-3 rounded-xl border border-n-weak bg-n-solid-2">
        <div class="text-xs text-n-slate-11">{{ t('CRM.DASHBOARD.KPIS.AVG_TICKET') }}</div>
        <div class="text-lg font-semibold text-n-slate-12">{{ formatCurrency(kpis.avg_implementation_ticket) }}</div>
      </div>
    </div>

    <div class="mb-6">
      <h3 class="mb-2 text-sm font-medium text-n-slate-12">{{ t('CRM.DASHBOARD.TREND.TITLE') }}</h3>
      <p v-if="!trend.length" class="text-sm text-n-slate-11">{{ t('CRM.DASHBOARD.EMPTY') }}</p>
      <div v-else class="flex flex-col gap-2">
        <div v-for="entry in trend" :key="entry.month" class="flex items-center gap-3 text-xs">
          <span class="w-16 text-n-slate-11">{{ entry.month }}</span>
          <div class="flex-1 flex flex-col gap-1">
            <div class="h-3 rounded bg-n-brand/70" :style="{ width: `${(entry.implementation_value / maxTrendValue) * 100}%` }" />
            <div class="h-3 rounded bg-n-teal-9/70" :style="{ width: `${(entry.monthly_value / maxTrendValue) * 100}%` }" />
          </div>
          <span class="w-28 text-right text-n-slate-11">
            {{ formatCurrency(entry.implementation_value) }} / {{ formatCurrency(entry.monthly_value) }}
          </span>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div>
        <h3 class="mb-2 text-sm font-medium text-n-slate-12">{{ t('CRM.DASHBOARD.RANKING.SELLERS') }}</h3>
        <div v-for="(seller, index) in sellerRanking" :key="seller.name" class="mb-2">
          <div class="flex items-center justify-between text-xs mb-1">
            <span class="font-medium text-n-slate-12">
              {{ index === 0 ? '★ ' : '' }}{{ seller.name }}
            </span>
            <span class="text-n-slate-11">{{ formatCurrency(seller.monthly_value) }}</span>
          </div>
          <div class="h-2 rounded bg-n-solid-3">
            <div class="h-2 rounded bg-n-brand" :style="{ width: `${(seller.monthly_value / maxSellerMonthly) * 100}%` }" />
          </div>
        </div>
        <p v-if="!sellerRanking.length" class="text-sm text-n-slate-11">{{ t('CRM.DASHBOARD.EMPTY') }}</p>
      </div>

      <div>
        <h3 class="mb-2 text-sm font-medium text-n-slate-12">{{ t('CRM.DASHBOARD.RANKING.PRODUCTS') }}</h3>
        <div v-for="product in productRanking" :key="product.product" class="flex items-center justify-between text-xs mb-2">
          <span class="text-n-slate-12">{{ product.product }}</span>
          <span class="text-n-slate-11">{{ formatCurrency(product.monthly_value) }}</span>
        </div>
        <p v-if="!productRanking.length" class="text-sm text-n-slate-11">{{ t('CRM.DASHBOARD.EMPTY') }}</p>
      </div>

      <div>
        <h3 class="mb-2 text-sm font-medium text-n-slate-12">{{ t('CRM.DASHBOARD.RANKING.CHANNELS') }}</h3>
        <div v-for="channel in channelRanking" :key="channel.channel" class="flex items-center justify-between text-xs mb-2">
          <span class="text-n-slate-12">{{ channel.channel }}</span>
          <span class="text-n-slate-11">{{ formatCurrency(channel.monthly_value) }} · {{ channel.unique_clients }} {{ t('CRM.DASHBOARD.RANKING.CLIENTS_SUFFIX') }}</span>
        </div>
        <p v-if="!channelRanking.length" class="text-sm text-n-slate-11">{{ t('CRM.DASHBOARD.EMPTY') }}</p>
      </div>
    </div>
  </div>
</template>
