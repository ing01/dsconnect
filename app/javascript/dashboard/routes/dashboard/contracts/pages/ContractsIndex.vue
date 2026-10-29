<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { useContractsStore } from 'dashboard/stores/contracts';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import ContractFormDialog from 'dashboard/components-next/Contracts/ContractFormDialog.vue';

const DEBOUNCE_DELAY = 300;

const { t } = useI18n();
const contractsStore = useContractsStore();
const route = useRoute();
const router = useRouter();

const goToCommercial = () =>
  router.push({
    name: 'crm_contracts_index',
    params: { accountId: route.params.accountId },
  });

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
    contractsStore.search(searchValue.value.trim(), page).then(results => {
      searchResults.value = results;
    });
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
        <div
          class="flex flex-col xs:flex-row items-start xs:items-center justify-between w-full py-7 gap-3 mx-auto max-w-5xl"
        >
          <div class="flex items-center min-w-0 gap-2">
            <Button
              ghost
              slate
              size="sm"
              icon="i-lucide-arrow-left"
              :label="t('CONTRACTS.BACK_TO_COMMERCIAL')"
              @click="goToCommercial"
            />
            <span class="text-xl font-medium truncate text-n-slate-12">
              {{ t('CONTRACTS.HEADER') }}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <Input
              :model-value="searchValue"
              type="search"
              :placeholder="t('CONTRACTS.SEARCH_PLACEHOLDER')"
              custom-input-class="h-9 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-9 !py-1 rtl:!pr-9"
              class="w-64"
              @input="onSearch($event.target.value)"
            >
              <template #prefix>
                <Icon
                  icon="i-lucide-search"
                  class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-3 rtl:right-3"
                />
              </template>
            </Input>
            <Button
              icon="i-lucide-plus"
              :label="t('CONTRACTS.ACTIONS.CREATE')"
              @click="openCreateDialog"
            />
          </div>
        </div>
      </header>

      <main class="flex-1 px-6 overflow-y-auto">
        <div class="w-full mx-auto max-w-5xl py-4">
          <div v-if="isFetching" class="flex items-center justify-center p-12">
            <span class="text-base text-n-slate-11">{{
              t('CONTRACTS.LOADING')
            }}</span>
          </div>
          <div
            v-else-if="!contracts.length"
            class="flex items-center justify-center p-12"
          >
            <span class="text-base text-n-slate-11">{{
              t('CONTRACTS.EMPTY_STATE')
            }}</span>
          </div>
          <div v-else class="flex flex-col gap-4">
            <CardLayout
              v-for="contract in contracts"
              :key="contract.id"
              layout="row"
              class="cursor-pointer"
              @click="openEditDialog(contract)"
            >
              <div class="flex flex-col gap-1.5 min-w-0 flex-1">
                <span class="text-base font-medium truncate text-n-slate-12">
                  {{ contract.displayLabel || t('CONTRACTS.NO_COMPANIES') }}
                </span>
                <div
                  class="flex flex-wrap items-center gap-x-5 gap-y-1.5 min-w-0"
                >
                  <span
                    v-if="contract.responsibleContact"
                    class="inline-flex items-center gap-1.5 text-sm text-n-slate-11 truncate"
                  >
                    <Icon
                      icon="i-lucide-user"
                      class="flex-shrink-0 size-4 text-n-slate-10"
                    />
                    {{ contract.responsibleContact.name }}
                  </span>
                  <span
                    class="inline-flex items-center gap-1.5 text-sm text-n-slate-11"
                  >
                    <Icon
                      icon="i-lucide-calendar-clock"
                      class="flex-shrink-0 size-4 text-n-slate-10"
                    />
                    {{
                      t(
                        `CONTRACTS.FORM.CONTRACT_TYPE.${(contract.contractType || '').toUpperCase()}`
                      )
                    }}
                  </span>
                  <span
                    class="inline-flex items-center gap-1.5 text-sm text-n-slate-11"
                  >
                    <Icon
                      icon="i-lucide-package"
                      class="flex-shrink-0 size-4 text-n-slate-10"
                    />
                    {{ contract.contractProductGroups?.length || 0 }}
                    {{ t('CONTRACTS.FORM.PRODUCTS.LABEL') }}
                  </span>
                  <span
                    v-if="contract.signedOn"
                    class="inline-flex items-center gap-1.5 text-sm text-n-slate-11"
                  >
                    <Icon
                      icon="i-lucide-signature"
                      class="flex-shrink-0 size-4 text-n-slate-10"
                    />
                    {{ contract.signedOn }}
                  </span>
                </div>
              </div>
              <span
                class="flex-shrink-0 text-base font-semibold text-n-slate-12"
              >
                {{ formatMoney(contract.computedTotalValue) }}
              </span>
            </CardLayout>
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

    <ContractFormDialog
      ref="formDialogRef"
      :is-loading="isSaving"
      @submit="handleSubmit"
    />
  </section>
</template>
