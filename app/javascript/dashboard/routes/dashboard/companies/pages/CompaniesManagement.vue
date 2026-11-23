<script setup>
// Gestao de clientes: lista as Empresas com filtros e altera varias de uma vez
// (nicho, subnicho, nivel, especialista, modulos, tipo de cobranca e status).
// Fica de fora da lista normal de Empresas de proposito: aqui o foco e' marcar
// muitas linhas e aplicar a mesma mudanca, nao abrir um cliente por vez.
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { debounce } from '@chatwoot/utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import CompaniesAPI from 'dashboard/api/companies';
import { useCompanyNichesStore } from 'dashboard/stores/companyNiches';
import { useCompanySubNichesStore } from 'dashboard/stores/companySubNiches';
import { useSystemModulesStore } from 'dashboard/stores/systemModules';

import Button from 'dashboard/components-next/button/Button.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';
import CompaniesBulkLog from 'dashboard/components-next/Companies/CompaniesBulkLog.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import {
  CLEAR_VALUE,
  LEVELS,
  buildBulkChanges,
  buildFilterParams,
} from './companiesManagementHelper';

const PER_PAGE = 25;
const DEBOUNCE_DELAY = 300;

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const nichesStore = useCompanyNichesStore();
const subNichesStore = useCompanySubNichesStore();
const modulesStore = useSystemModulesStore();

const niches = computed(() => nichesStore.getNiches);
const subNiches = computed(() => subNichesStore.getSubNiches);
const systemModules = computed(() => modulesStore.getModules);

const filters = reactive({
  q: '',
  status: '',
  classificationLevel: '',
  companyNicheId: '',
  companySubNicheId: '',
  specialistId: '',
});
const page = ref(1);
const companies = ref([]);
const total = ref(0);
const isLoading = ref(false);
let requestToken = 0;

const fetchCompanies = async () => {
  requestToken += 1;
  const token = requestToken;
  isLoading.value = true;
  try {
    const query = filters.q.trim();
    const response = query
      ? await CompaniesAPI.search(
          query,
          page.value,
          'name',
          filters.classificationLevel,
          filters.companyNicheId,
          filters.specialistId,
          filters.companySubNicheId,
          filters.status
        )
      : await CompaniesAPI.get({
          page: page.value,
          sort: 'name',
          classificationLevel: filters.classificationLevel,
          companyNicheId: filters.companyNicheId,
          specialistId: filters.specialistId,
          companySubNicheId: filters.companySubNicheId,
          status: filters.status,
        });
    // Uma resposta antiga (mais lenta) nao pode sobrescrever a mais nova.
    if (token !== requestToken) return;
    companies.value = camelcaseKeys(response.data?.payload || [], {
      deep: true,
      stopPaths: ['custom_attributes'],
    });
    total.value = Number(response.data?.meta?.total_count || 0);
  } catch (error) {
    if (token !== requestToken) return;
    companies.value = [];
    total.value = 0;
    useAlert(t('COMPANIES.MANAGEMENT.LOAD_ERROR'));
  } finally {
    if (token === requestToken) isLoading.value = false;
  }
};

// ---- Selecao -------------------------------------------------------------
const selectedIds = ref([]);
// Marca todos os clientes que o filtro encontra, inclusive os de outras paginas.
const selectAllMatching = ref(false);

const selectedCount = computed(() =>
  selectAllMatching.value ? total.value : selectedIds.value.length
);
const pageIds = computed(() => companies.value.map(company => company.id));
const isPageSelected = computed(
  () =>
    pageIds.value.length > 0 &&
    (selectAllMatching.value ||
      pageIds.value.every(id => selectedIds.value.includes(id)))
);
const canOfferSelectAll = computed(
  () =>
    isPageSelected.value && !selectAllMatching.value && total.value > PER_PAGE
);

const isSelected = id =>
  selectAllMatching.value || selectedIds.value.includes(id);

const toggleRow = id => {
  // Desmarcar uma linha sai do "todos os resultados": passa a valer a lista
  // explicita, sem a linha desmarcada.
  if (selectAllMatching.value) {
    selectedIds.value = pageIds.value.filter(pageId => pageId !== id);
    selectAllMatching.value = false;
    return;
  }
  selectedIds.value = selectedIds.value.includes(id)
    ? selectedIds.value.filter(selected => selected !== id)
    : [...selectedIds.value, id];
};

const togglePage = () => {
  if (isPageSelected.value) {
    selectedIds.value = selectedIds.value.filter(
      id => !pageIds.value.includes(id)
    );
    selectAllMatching.value = false;
    return;
  }
  selectedIds.value = [...new Set([...selectedIds.value, ...pageIds.value])];
};

const clearSelection = () => {
  selectedIds.value = [];
  selectAllMatching.value = false;
};

// ---- Filtros -------------------------------------------------------------
const applyFilters = () => {
  page.value = 1;
  clearSelection();
  fetchCompanies();
};
const onSearchInput = debounce(applyFilters, DEBOUNCE_DELAY);

const onPageChange = newPage => {
  page.value = newPage;
  fetchCompanies();
};

// ---- Alteracao em massa --------------------------------------------------
const emptyBulk = () => ({
  status: '',
  classificationLevel: '',
  companyNicheId: '',
  companySubNicheId: '',
  specialistId: '',
  billingType: '',
  modules: [],
  modulesMode: 'add',
});
const bulk = reactive(emptyBulk());
const isConfirming = ref(false);
const isApplying = ref(false);
const logRef = ref(null);

const bulkChanges = computed(() => buildBulkChanges(bulk));
const hasChanges = computed(() => Object.keys(bulkChanges.value).length > 0);
const canApply = computed(() => selectedCount.value > 0 && hasChanges.value);

const resetBulk = () => {
  Object.assign(bulk, emptyBulk());
  isConfirming.value = false;
};

const toggleBulkModule = id => {
  bulk.modules = bulk.modules.includes(id)
    ? bulk.modules.filter(moduleId => moduleId !== id)
    : [...bulk.modules, id];
};

const applyBulk = async () => {
  isApplying.value = true;
  try {
    const payload = {
      changes: bulkChanges.value,
      ...(selectAllMatching.value
        ? { select_all: true, ...buildFilterParams(filters) }
        : { ids: selectedIds.value }),
    };
    // O servidor responde na hora e aplica em segundo plano.
    const { data } = await CompaniesAPI.bulkUpdate(payload);
    useAlert(
      t('COMPANIES.MANAGEMENT.BULK.QUEUED', { count: data.queued }, data.queued)
    );
    resetBulk();
    clearSelection();
    // O log acompanha o andamento e, quando termina, recarrega a lista.
    await logRef.value?.reload();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('COMPANIES.MANAGEMENT.BULK.ERROR')
    );
    isConfirming.value = false;
  } finally {
    isApplying.value = false;
  }
};

// ---- Exibicao ------------------------------------------------------------
const levelLabel = level =>
  level ? t('COMPANIES.LEVEL_BADGE', { n: level }) : '';
const billingLabel = type =>
  type
    ? t(`COMPANIES.DETAIL.PROFILE.BILLING.${String(type).toUpperCase()}`)
    : '';
const statusLabel = status =>
  t(`COMPANIES.MANAGEMENT.STATUS.${String(status || 'active').toUpperCase()}`);
const moduleNames = company =>
  (company.systemModules || []).map(item => item.name).join(', ');

const selectClass =
  'h-9 px-2 text-sm border rounded-lg bg-n-background border-n-strong text-n-slate-12 min-w-0';

onMounted(() => {
  if (!niches.value.length) nichesStore.get();
  if (!subNiches.value.length) subNichesStore.get();
  if (!systemModules.value.length) modulesStore.get();
  if (!agents.value.length) store.dispatch('agents/get');
  fetchCompanies();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="px-6 pt-6 pb-3">
      <h1 class="m-0 text-xl font-medium text-n-slate-12">
        {{ t('COMPANIES.MANAGEMENT.TITLE') }}
      </h1>
      <p class="mt-1 mb-0 text-sm text-n-slate-11">
        {{ t('COMPANIES.MANAGEMENT.SUBTITLE') }}
      </p>
    </header>

    <!-- Filtros -->
    <div class="grid grid-cols-2 gap-2 px-6 pb-3 md:grid-cols-4 xl:grid-cols-7">
      <input
        v-model="filters.q"
        type="search"
        :placeholder="t('COMPANIES.MANAGEMENT.SEARCH_PLACEHOLDER')"
        :aria-label="t('COMPANIES.MANAGEMENT.SEARCH_PLACEHOLDER')"
        :class="[selectClass, 'col-span-2 md:col-span-1 xl:col-span-2']"
        @input="onSearchInput"
      />
      <select
        v-model="filters.status"
        :class="selectClass"
        :aria-label="t('COMPANIES.MANAGEMENT.COLUMNS.STATUS')"
        @change="applyFilters"
      >
        <option value="">{{ t('COMPANIES.MANAGEMENT.FILTERS.ALL_STATUSES') }}</option>
        <option value="active">{{ t('COMPANIES.MANAGEMENT.STATUS.ACTIVE') }}</option>
        <option value="inactive">
          {{ t('COMPANIES.MANAGEMENT.STATUS.INACTIVE') }}
        </option>
      </select>
      <select
        v-model="filters.classificationLevel"
        :class="selectClass"
        :aria-label="t('COMPANIES.MANAGEMENT.COLUMNS.LEVEL')"
        @change="applyFilters"
      >
        <option value="">{{ t('COMPANIES.MANAGEMENT.FILTERS.ALL_LEVELS') }}</option>
        <option v-for="level in LEVELS" :key="level" :value="level">
          {{ levelLabel(level) }}
        </option>
      </select>
      <select
        v-model="filters.companyNicheId"
        :class="selectClass"
        :aria-label="t('COMPANIES.MANAGEMENT.COLUMNS.NICHE')"
        @change="applyFilters"
      >
        <option value="">{{ t('COMPANIES.MANAGEMENT.FILTERS.ALL_NICHES') }}</option>
        <option v-for="niche in niches" :key="niche.id" :value="niche.id">
          {{ niche.name }}
        </option>
      </select>
      <select
        v-model="filters.companySubNicheId"
        :class="selectClass"
        :aria-label="t('COMPANIES.MANAGEMENT.COLUMNS.SUB_NICHE')"
        @change="applyFilters"
      >
        <option value="">
          {{ t('COMPANIES.MANAGEMENT.FILTERS.ALL_SUB_NICHES') }}
        </option>
        <option v-for="item in subNiches" :key="item.id" :value="item.id">
          {{ item.name }}
        </option>
      </select>
      <select
        v-model="filters.specialistId"
        :class="selectClass"
        :aria-label="t('COMPANIES.MANAGEMENT.COLUMNS.SPECIALIST')"
        @change="applyFilters"
      >
        <option value="">
          {{ t('COMPANIES.MANAGEMENT.FILTERS.ALL_SPECIALISTS') }}
        </option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
    </div>

    <!-- Alteracao em massa -->
    <div
      class="flex flex-col gap-3 p-4 mx-6 mb-3 border rounded-xl border-n-weak bg-n-alpha-1"
      data-testid="bulk-panel"
    >
      <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.MANAGEMENT.BULK.TITLE') }}
        </span>
        <span class="text-sm text-n-slate-11" data-testid="selected-count">
          {{
            t(
              'COMPANIES.MANAGEMENT.BULK.SELECTED',
              { count: selectedCount },
              selectedCount
            )
          }}
        </span>
        <Button
          v-if="canOfferSelectAll"
          link
          xs
          data-testid="select-all-matching"
          :label="t('COMPANIES.MANAGEMENT.BULK.SELECT_ALL', { count: total })"
          @click="selectAllMatching = true"
        />
        <Button
          v-if="selectedCount"
          link
          slate
          xs
          :label="t('COMPANIES.MANAGEMENT.BULK.CLEAR_SELECTION')"
          @click="clearSelection"
        />
      </div>

      <div class="grid grid-cols-2 gap-2 md:grid-cols-4 xl:grid-cols-6">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.COLUMNS.STATUS') }}
          </span>
          <select v-model="bulk.status" :class="selectClass">
            <option value="">{{ t('COMPANIES.MANAGEMENT.BULK.KEEP') }}</option>
            <option value="active">
              {{ t('COMPANIES.MANAGEMENT.STATUS.ACTIVE') }}
            </option>
            <option value="inactive">
              {{ t('COMPANIES.MANAGEMENT.STATUS.INACTIVE') }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.COLUMNS.LEVEL') }}
          </span>
          <select v-model="bulk.classificationLevel" :class="selectClass">
            <option value="">{{ t('COMPANIES.MANAGEMENT.BULK.KEEP') }}</option>
            <option :value="CLEAR_VALUE">
              {{ t('COMPANIES.MANAGEMENT.BULK.CLEAR') }}
            </option>
            <option v-for="level in LEVELS" :key="level" :value="level">
              {{ levelLabel(level) }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.COLUMNS.NICHE') }}
          </span>
          <select v-model="bulk.companyNicheId" :class="selectClass">
            <option value="">{{ t('COMPANIES.MANAGEMENT.BULK.KEEP') }}</option>
            <option :value="CLEAR_VALUE">
              {{ t('COMPANIES.MANAGEMENT.BULK.CLEAR') }}
            </option>
            <option v-for="niche in niches" :key="niche.id" :value="niche.id">
              {{ niche.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.COLUMNS.SUB_NICHE') }}
          </span>
          <select v-model="bulk.companySubNicheId" :class="selectClass">
            <option value="">{{ t('COMPANIES.MANAGEMENT.BULK.KEEP') }}</option>
            <option :value="CLEAR_VALUE">
              {{ t('COMPANIES.MANAGEMENT.BULK.CLEAR') }}
            </option>
            <option v-for="item in subNiches" :key="item.id" :value="item.id">
              {{ item.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.COLUMNS.SPECIALIST') }}
          </span>
          <select v-model="bulk.specialistId" :class="selectClass">
            <option value="">{{ t('COMPANIES.MANAGEMENT.BULK.KEEP') }}</option>
            <option :value="CLEAR_VALUE">
              {{ t('COMPANIES.MANAGEMENT.BULK.CLEAR') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.MANAGEMENT.COLUMNS.BILLING') }}
          </span>
          <select v-model="bulk.billingType" :class="selectClass">
            <option value="">{{ t('COMPANIES.MANAGEMENT.BULK.KEEP') }}</option>
            <option value="monthly">
              {{ t('COMPANIES.DETAIL.PROFILE.BILLING.MONTHLY') }}
            </option>
            <option value="annual">
              {{ t('COMPANIES.DETAIL.PROFILE.BILLING.ANNUAL') }}
            </option>
          </select>
        </label>
      </div>

      <!-- Modulos: marca os que entram/saem e diz como aplicar. -->
      <details class="text-sm" data-testid="modules-panel">
        <summary class="cursor-pointer text-n-slate-12">
          {{ t('COMPANIES.MANAGEMENT.COLUMNS.MODULES') }}
          <span v-if="bulk.modules.length" class="text-n-slate-11">
            ({{ bulk.modules.length }})
          </span>
        </summary>
        <div class="flex flex-col gap-2 mt-2">
          <div class="flex flex-wrap gap-3">
            <label
              v-for="mode in ['add', 'remove', 'replace']"
              :key="mode"
              class="flex items-center gap-1 text-n-slate-11"
            >
              <input v-model="bulk.modulesMode" type="radio" :value="mode" />
              {{ t(`COMPANIES.MANAGEMENT.BULK.MODULES_MODE.${mode.toUpperCase()}`) }}
            </label>
          </div>
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <label
              v-for="item in systemModules"
              :key="item.id"
              class="flex items-center gap-1 text-n-slate-12"
            >
              <input
                type="checkbox"
                :checked="bulk.modules.includes(item.id)"
                @change="toggleBulkModule(item.id)"
              />
              {{ item.name }}
            </label>
          </div>
        </div>
      </details>

      <div class="flex flex-wrap items-center justify-end gap-2">
        <template v-if="isConfirming">
          <span class="text-sm text-n-slate-12" data-testid="confirm-text">
            {{
              t(
                'COMPANIES.MANAGEMENT.BULK.CONFIRM',
                { count: selectedCount },
                selectedCount
              )
            }}
          </span>
          <Button
            ghost
            slate
            size="sm"
            :label="t('COMPANIES.MANAGEMENT.BULK.CANCEL')"
            :disabled="isApplying"
            @click="isConfirming = false"
          />
          <Button
            size="sm"
            data-testid="confirm-apply"
            :label="t('COMPANIES.MANAGEMENT.BULK.CONFIRM_BUTTON')"
            :is-loading="isApplying"
            @click="applyBulk"
          />
        </template>
        <template v-else>
          <Button
            ghost
            slate
            size="sm"
            :label="t('COMPANIES.MANAGEMENT.BULK.RESET')"
            :disabled="!hasChanges"
            @click="resetBulk"
          />
          <Button
            size="sm"
            data-testid="apply"
            :label="t('COMPANIES.MANAGEMENT.BULK.APPLY')"
            :disabled="!canApply"
            @click="isConfirming = true"
          />
        </template>
      </div>
    </div>

    <CompaniesBulkLog ref="logRef" @finished="fetchCompanies" />

    <!-- Lista -->
    <main class="flex-1 px-6 overflow-auto">
      <PageLoader v-if="isLoading && !companies.length" />
      <p
        v-else-if="!companies.length"
        class="py-10 text-base text-center text-n-slate-11"
      >
        {{ t('COMPANIES.MANAGEMENT.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm text-left border-collapse">
        <thead class="sticky top-0 z-10 bg-n-surface-1 text-n-slate-11">
          <tr class="border-b border-n-weak">
            <th class="w-8 py-2 pr-2">
              <input
                type="checkbox"
                :checked="isPageSelected"
                :aria-label="t('COMPANIES.MANAGEMENT.BULK.SELECT_PAGE')"
                data-testid="select-page"
                @change="togglePage"
              />
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.NAME') }}
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.LEVEL') }}
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.NICHE') }}
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.SUB_NICHE') }}
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.SPECIALIST') }}
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.MODULES') }}
            </th>
            <th class="py-2 pr-3 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.BILLING') }}
            </th>
            <th class="py-2 font-medium">
              {{ t('COMPANIES.MANAGEMENT.COLUMNS.STATUS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="company in companies"
            :key="company.id"
            class="border-b border-n-weak hover:bg-n-alpha-1"
            data-testid="company-row"
          >
            <td class="py-2 pr-2">
              <input
                type="checkbox"
                :checked="isSelected(company.id)"
                :aria-label="company.name"
                @change="toggleRow(company.id)"
              />
            </td>
            <td class="py-2 pr-3 max-w-64">
              <div class="truncate text-n-slate-12" :title="company.name">
                {{ company.name }}
              </div>
              <div v-if="company.codigo" class="text-xs font-mono text-n-slate-11">
                {{ company.codigo }}
              </div>
            </td>
            <td class="py-2 pr-3 text-n-slate-12">
              {{ levelLabel(company.classificationLevel) || '—' }}
            </td>
            <td class="py-2 pr-3 text-n-slate-12">
              {{ company.companyNiche?.name || '—' }}
            </td>
            <td class="py-2 pr-3 text-n-slate-12">
              {{ company.companySubNiche?.name || '—' }}
            </td>
            <td class="py-2 pr-3 text-n-slate-12">
              {{ company.specialist?.name || '—' }}
            </td>
            <td
              class="py-2 pr-3 truncate max-w-56 text-n-slate-12"
              :title="moduleNames(company)"
            >
              {{ moduleNames(company) || '—' }}
            </td>
            <td class="py-2 pr-3 text-n-slate-12">
              {{ billingLabel(company.billingType) || '—' }}
            </td>
            <td class="py-2">
              <span
                class="inline-flex px-2 py-0.5 text-xs font-semibold rounded-md"
                :class="
                  company.status === 'inactive'
                    ? 'bg-n-slate-3 text-n-slate-11'
                    : 'bg-n-teal-3 text-n-teal-11'
                "
              >
                {{ statusLabel(company.status) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </main>

    <footer v-if="companies.length" class="sticky bottom-0 z-0">
      <PaginationFooter
        current-page-info="COMPANIES_LAYOUT.PAGINATION_FOOTER.SHOWING"
        :current-page="page"
        :total-items="total"
        :items-per-page="PER_PAGE"
        @update:current-page="onPageChange"
      />
    </footer>
  </section>
</template>
