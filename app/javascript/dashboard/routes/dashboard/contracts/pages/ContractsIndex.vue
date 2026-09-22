<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { useContractsStore } from 'dashboard/stores/contracts';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import ContractFormDialog from 'dashboard/components-next/Contracts/ContractFormDialog.vue';

const DEBOUNCE_DELAY = 300;

const { t } = useI18n();
const contractsStore = useContractsStore();

const searchValue = ref('');
const currentPage = ref(1);
const searchResults = ref(null);
const formDialogRef = ref(null);

const contracts = computed(
  () => searchResults.value ?? contractsStore.getContracts
);
const meta = computed(() => contractsStore.getMeta);
const uiFlags = computed(() => contractsStore.uiFlags);
const isFetching = computed(
  () => uiFlags.value.isFetching || uiFlags.value.isSearching
);
const isSaving = computed(
  () => uiFlags.value.isCreating || uiFlags.value.isUpdating
);

const fetchPage = page => {
  currentPage.value = page;
  if (searchValue.value.trim()) {
    contractsStore
      .search(searchValue.value.trim(), page)
      .then(results => (searchResults.value = results));
  } else {
    searchResults.value = null;
    contractsStore.get(page);
  }
};

const onSearch = debounce(value => {
  searchValue.value = value;
  fetchPage(1);
}, DEBOUNCE_DELAY);

const onPageChange = page => fetchPage(page);

const formatMoney = value =>
  Number(value || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  });

const openCreateDialog = () => formDialogRef.value?.open();
const openEditDialog = contract => formDialogRef.value?.open(contract);

const handleSubmit = async payload => {
  try {
    if (payload.id) {
      await contractsStore.update(payload.id, payload);
      useAlert(t('CONTRACTS.MESSAGES.UPDATE_SUCCESS'));
    } else {
      await contractsStore.create(payload);
      useAlert(t('CONTRACTS.MESSAGES.CREATE_SUCCESS'));
    }
    formDialogRef.value?.onSuccess();
    fetchPage(currentPage.value);
  } catch {
    useAlert(t('CONTRACTS.MESSAGES.SAVE_ERROR'));
  }
};

onMounted(() => fetchPage(1));
</script>

<template>
  <section class="flex w-full h-full overflow-hidden bg-n-surface-1">
    <div class="flex flex-col w-full h-full">
      <header class="sticky top-0 z-10 px-6">
        <div class="flex items-center justify-between w-full py-6 gap-2 mx-auto max-w-5xl">
          <span class="text-xl font-medium truncate text-n-slate-12">
            {{ t('CONTRACTS.HEADER') }}
          </span>
          <div class="flex items-center gap-2">
            <Input
              :model-value="searchValue"
              type="search"
              :placeholder="t('CONTRACTS.SEARCH_PLACEHOLDER')"
              custom-input-class="h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8"
              @input="onSearch($event.target.value)"
            >
              <template #prefix>
                <Icon icon="i-lucide-search" class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2" />
              </template>
            </Input>
            <Button icon="i-lucide-plus" size="sm" :label="t('CONTRACTS.ACTIONS.CREATE')" @click="openCreateDialog" />
          </div>
        </div>
      </header>

      <main class="flex-1 px-6 overflow-y-auto">
        <div class="w-full mx-auto max-w-5xl py-4">
          <div v-if="isFetching" class="flex items-center justify-center p-8">
            <span class="text-base text-n-slate-11">{{ t('CONTRACTS.LOADING') }}</span>
          </div>
          <div v-else-if="!contracts.length" class="flex items-center justify-center p-8">
            <span class="text-base text-n-slate-11">{{ t('CONTRACTS.EMPTY_STATE') }}</span>
          </div>
          <div v-else class="flex flex-col gap-3">
            <button
              v-for="contract in contracts"
              :key="contract.id"
              type="button"
              class="flex flex-col items-start gap-2 p-4 text-left rounded-xl border border-n-weak bg-n-solid-1 hover:border-n-slate-6 hover:shadow-sm transition-all"
              @click="openEditDialog(contract)"
            >
              <div class="flex items-center justify-between w-full gap-2">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ contract.companies?.map(c => c.name).join(', ') || t('CONTRACTS.NO_COMPANIES') }}
                </span>
                <span class="text-sm font-medium text-n-slate-12">{{ formatMoney(contract.computedTotalValue) }}</span>
              </div>
              <div class="flex items-center gap-3 text-xs text-n-slate-11">
                <span v-if="contract.responsibleContact">{{ t('CONTRACTS.FORM.RESPONSIBLE.LABEL') }}: {{ contract.responsibleContact.name }}</span>
                <span>{{ t(`CONTRACTS.FORM.CONTRACT_TYPE.${(contract.contractType || '').toUpperCase()}`) }}</span>
                <span>{{ contract.contractProducts?.length || 0 }} {{ t('CONTRACTS.FORM.PRODUCTS.LABEL') }}</span>
              </div>
            </button>
          </div>
        </div>
      </main>

      <footer v-if="contracts.length" class="sticky bottom-0 z-0">
        <PaginationFooter
          current-page-info="COMPANIES_LAYOUT.PAGINATION_FOOTER.SHOWING"
          :current-page="currentPage"
          :total-items="Number(meta.totalCount || 0)"
          :items-per-page="25"
          class="max-w-5xl mx-auto"
          @update:current-page="onPageChange"
        />
      </footer>
    </div>

    <ContractFormDialog ref="formDialogRef" :is-loading="isSaving" @submit="handleSubmit" />
  </section>
</template>
