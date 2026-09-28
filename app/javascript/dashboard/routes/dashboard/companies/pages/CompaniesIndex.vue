<script setup>
import { ref, computed, onMounted, reactive } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { debounce } from '@chatwoot/utils';
import { useCompaniesStore } from 'dashboard/stores/companies';

import CompaniesListLayout from 'dashboard/components-next/Companies/CompaniesListLayout.vue';
import CompaniesCard from 'dashboard/components-next/Companies/CompaniesCard/CompaniesCard.vue';
import CompanyCreateDialog from 'dashboard/components-next/Companies/CompanyCreateDialog.vue';

const DEFAULT_SORT_FIELD = 'name';
const DEBOUNCE_DELAY = 300;

const companiesStore = useCompaniesStore();

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const { updateUISettings, uiSettings } = useUISettings();

const companies = computed(() => companiesStore.getCompaniesList);
const meta = computed(() => companiesStore.getMeta);
const uiFlags = computed(() => companiesStore.getUIFlags);

const searchQuery = computed(() => route.query?.search || '');
const searchValue = ref(searchQuery.value);
const createCompanyDialogRef = ref(null);
const pageNumber = computed(() => Number(route.query?.page) || 1);
const clientLevelQuery = computed(() => route.query?.client_level || '');
const activeClientLevel = ref(
  clientLevelQuery.value ? Number(clientLevelQuery.value) : ''
);

const parseSortSettings = (sortString = '') => {
  const hasDescending = sortString.startsWith('-');
  const sortField = hasDescending ? sortString.slice(1) : sortString;
  return {
    sort: sortField || DEFAULT_SORT_FIELD,
    order: hasDescending ? '-' : '',
  };
};

const { companies_sort_by: companySortBy = DEFAULT_SORT_FIELD } =
  uiSettings.value ?? {};
const { sort: initialSort, order: initialOrder } =
  parseSortSettings(companySortBy);

const sortState = reactive({
  activeSort: initialSort,
  activeOrdering: initialOrder,
});

const activeSort = computed(() => sortState.activeSort);
const activeOrdering = computed(() => sortState.activeOrdering);

const isFetchingList = computed(() => uiFlags.value.fetchingList);
const isCreatingCompany = computed(() => uiFlags.value.creatingItem);

const buildSortAttr = () =>
  `${sortState.activeOrdering}${sortState.activeSort}`;

const sortParam = computed(() => buildSortAttr());

const updateURLParams = (page, search = '', sort = '', clientLevel = '') => {
  const query = {
    ...route.query,
    page: page.toString(),
  };

  if (search) {
    query.search = search;
  } else {
    delete query.search;
  }

  if (sort) {
    query.sort = sort;
  } else {
    delete query.sort;
  }

  if (clientLevel) {
    query.client_level = clientLevel.toString();
  } else {
    delete query.client_level;
  }

  router.replace({ query });
};

const fetchCompanies = async (page, search, sort) => {
  const currentPage = page ?? pageNumber.value;
  const currentSearch = search ?? searchQuery.value;
  const currentSort = sort ?? sortParam.value;
  const currentClientLevel = activeClientLevel.value;

  // Only update URL if arguments were explicitly provided
  if (page !== undefined || search !== undefined || sort !== undefined) {
    updateURLParams(currentPage, currentSearch, currentSort, currentClientLevel);
  }

  if (currentSearch) {
    await companiesStore.search({
      search: currentSearch,
      page: currentPage,
      sort: currentSort,
      clientLevel: currentClientLevel,
    });
  } else {
    await companiesStore.get({
      page: currentPage,
      sort: currentSort,
      clientLevel: currentClientLevel,
    });
  }
};

const onSearch = debounce(query => {
  searchValue.value = query;
  fetchCompanies(1, query, sortParam.value);
}, DEBOUNCE_DELAY);

const onPageChange = page => {
  fetchCompanies(page, searchValue.value, sortParam.value);
};

const showCompany = companyId => {
  router.push({
    name: 'companies_dashboard_show',
    params: {
      accountId: route.params.accountId,
      companyId,
    },
  });
};

const openCreateCompanyDialog = () => {
  createCompanyDialogRef.value?.open();
};

const createCompany = async company => {
  try {
    const newCompany = await companiesStore.create(company);
    createCompanyDialogRef.value?.onSuccess();
    useAlert(t('COMPANIES.CREATE.MESSAGES.SUCCESS'));
    showCompany(newCompany.id);
  } catch {
    useAlert(t('COMPANIES.CREATE.MESSAGES.ERROR'));
  }
};

const handleSort = async ({ sort, order }) => {
  Object.assign(sortState, { activeSort: sort, activeOrdering: order });

  await updateUISettings({
    companies_sort_by: buildSortAttr(),
  });

  fetchCompanies(1, searchValue.value, buildSortAttr());
};

const handleClientLevelChange = clientLevel => {
  activeClientLevel.value = clientLevel;
  fetchCompanies(1, searchValue.value, sortParam.value);
};

onMounted(() => {
  searchValue.value = searchQuery.value;

  if (!route.query.sort && sortParam.value !== DEFAULT_SORT_FIELD) {
    updateURLParams(pageNumber.value, searchQuery.value, sortParam.value);
  }

  fetchCompanies();
});
</script>

<template>
  <CompaniesListLayout
    :search-value="searchValue"
    :header-title="t('COMPANIES.HEADER')"
    :current-page="pageNumber"
    :total-items="Number(meta.totalCount || 0)"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    :active-client-level="activeClientLevel"
    :is-fetching-list="isFetchingList"
    :show-pagination-footer="!!companies.length"
    @update:current-page="onPageChange"
    @update:sort="handleSort"
    @update:client-level="handleClientLevelChange"
    @search="onSearch"
    @create="openCreateCompanyDialog"
  >
    <div v-if="isFetchingList" class="flex items-center justify-center p-8">
      <span class="text-n-slate-11 text-base">{{
        t('COMPANIES.LOADING')
      }}</span>
    </div>
    <div
      v-else-if="companies.length === 0"
      class="flex items-center justify-center p-8"
    >
      <span class="text-n-slate-11 text-base">{{
        t('COMPANIES.EMPTY_STATE.TITLE')
      }}</span>
    </div>
    <div v-else class="flex flex-col gap-4">
      <CompaniesCard
        v-for="company in companies"
        :id="company.id"
        :key="company.id"
        :name="company.name"
        :domain="company.domain"
        :contacts-count="company.contactsCount || 0"
        :avatar-url="company.avatarUrl"
        :last-activity-at="company.lastActivityAt"
        :legal-name="company.legalName"
        :cnpj="company.cnpj"
        :codigo="company.codigo"
        :client-level="company.clientLevel"
        @show-company="showCompany"
      />
    </div>
    <CompanyCreateDialog
      ref="createCompanyDialogRef"
      :is-loading="isCreatingCompany"
      @create="createCompany"
    />
  </CompaniesListLayout>
</template>
