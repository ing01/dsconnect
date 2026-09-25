<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useProductGroupsStore } from 'dashboard/stores/productGroups';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ProductGroupFormDialog from './ProductGroupFormDialog.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const productGroupsStore = useProductGroupsStore();

const formDialogRef = ref(null);
const selectedProductGroup = ref(null);
const showDeleteConfirmationPopup = ref(false);

const productGroups = computed(() => productGroupsStore.getProductGroups);
const uiFlags = computed(() => productGroupsStore.uiFlags);
const isSaving = computed(() => uiFlags.value.isCreating || uiFlags.value.isUpdating);

const tableHeaders = computed(() => [
  t('PRODUCT_GROUPS.FORM.NAME'),
  t('PRODUCT_GROUPS.LIST.PRODUCTS_COUNT'),
  t('PRODUCT_GROUPS.LIST.VALUE'),
  '',
]);

const formatMoney = value =>
  Number(value || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

const openCreateDialog = () => formDialogRef.value?.open();
const openEditDialog = productGroup => formDialogRef.value?.open(productGroup);

const handleSubmit = async payload => {
  try {
    if (payload.id) {
      await productGroupsStore.update(payload.id, payload);
      useAlert(t('PRODUCT_GROUPS.MESSAGES.UPDATE_SUCCESS'));
    } else {
      await productGroupsStore.create(payload);
      useAlert(t('PRODUCT_GROUPS.MESSAGES.CREATE_SUCCESS'));
    }
    formDialogRef.value?.onSuccess();
  } catch {
    useAlert(t('PRODUCT_GROUPS.MESSAGES.SAVE_ERROR'));
  }
};

const openDeletePopup = productGroup => {
  selectedProductGroup.value = productGroup;
  showDeleteConfirmationPopup.value = true;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = async () => {
  closeDeletePopup();
  try {
    await productGroupsStore.delete(selectedProductGroup.value.id);
    useAlert(t('PRODUCT_GROUPS.MESSAGES.DELETE_SUCCESS'));
  } catch {
    useAlert(t('PRODUCT_GROUPS.MESSAGES.DELETE_ERROR'));
  }
};

onBeforeMount(() => {
  productGroupsStore.get();
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('PRODUCT_GROUPS.LOADING')"
    :no-records-found="!productGroups.length"
    :no-records-message="t('PRODUCT_GROUPS.EMPTY_STATE')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('PRODUCT_GROUPS.HEADER')"
        :description="t('PRODUCT_GROUPS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            icon="i-lucide-plus"
            size="sm"
            :label="t('PRODUCT_GROUPS.ADD_BUTTON')"
            @click="openCreateDialog"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable :headers="tableHeaders" :items="productGroups">
        <template #row="{ items }">
          <BaseTableRow v-for="group in items" :key="group.id" :item="group">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ group.name }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ group.products?.length || 0 }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ formatMoney(group.computedValue) }}
                  <span v-if="group.totalValueMode === 'manual'" class="text-xs text-n-slate-10">
                    ({{ t('PRODUCT_GROUPS.LIST.MANUAL_BADGE') }})
                  </span>
                </span>
              </BaseTableCell>
              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditDialog(group)"
                  />
                  <Button
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(group)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <ProductGroupFormDialog ref="formDialogRef" :is-loading="isSaving" @submit="handleSubmit" />

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('PRODUCT_GROUPS.DELETE_CONFIRM')"
      :message="''"
      :message-value="selectedProductGroup?.name"
      :confirm-text="t('PRODUCTS.DELETE_CONFIRM_YES')"
      :reject-text="t('PRODUCTS.DELETE_CONFIRM_NO')"
    />
  </SettingsLayout>
</template>
