<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useProductsStore } from 'dashboard/stores/products';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ProductFormDialog from './ProductFormDialog.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const productsStore = useProductsStore();

const formDialogRef = ref(null);
const selectedProduct = ref(null);
const showDeleteConfirmationPopup = ref(false);

const products = computed(() => productsStore.getProducts);
const uiFlags = computed(() => productsStore.uiFlags);
const isSaving = computed(() => uiFlags.value.isCreating || uiFlags.value.isUpdating);

const tableHeaders = computed(() => [
  t('PRODUCTS.FORM.NAME'),
  t('PRODUCTS.FORM.GROUP'),
  t('PRODUCTS.FORM.VALUE'),
  '',
]);

const formatMoney = value =>
  value == null
    ? '—'
    : Number(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

const openCreateDialog = () => formDialogRef.value?.open();
const openEditDialog = product => formDialogRef.value?.open(product);

const handleSubmit = async payload => {
  try {
    if (payload.id) {
      await productsStore.update(payload.id, payload);
      useAlert(t('PRODUCTS.MESSAGES.UPDATE_SUCCESS'));
    } else {
      await productsStore.create(payload);
      useAlert(t('PRODUCTS.MESSAGES.CREATE_SUCCESS'));
    }
    formDialogRef.value?.onSuccess();
  } catch {
    useAlert(t('PRODUCTS.MESSAGES.SAVE_ERROR'));
  }
};

const openDeletePopup = product => {
  selectedProduct.value = product;
  showDeleteConfirmationPopup.value = true;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = async () => {
  closeDeletePopup();
  try {
    await productsStore.delete(selectedProduct.value.id);
    useAlert(t('PRODUCTS.MESSAGES.DELETE_SUCCESS'));
  } catch {
    useAlert(t('PRODUCTS.MESSAGES.DELETE_ERROR'));
  }
};

onBeforeMount(() => {
  productsStore.get();
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('PRODUCTS.LOADING')"
    :no-records-found="!products.length"
    :no-records-message="t('PRODUCTS.EMPTY_STATE')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('PRODUCTS.HEADER')"
        :description="t('PRODUCTS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            icon="i-lucide-plus"
            size="sm"
            :label="t('PRODUCTS.ADD_BUTTON')"
            @click="openCreateDialog"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable :headers="tableHeaders" :items="products">
        <template #row="{ items }">
          <BaseTableRow v-for="product in items" :key="product.id" :item="product">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ product.name }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ product.productGroupName || '—' }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ formatMoney(product.value) }}
                </span>
              </BaseTableCell>
              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditDialog(product)"
                  />
                  <Button
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(product)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <ProductFormDialog ref="formDialogRef" :is-loading="isSaving" @submit="handleSubmit" />

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('PRODUCTS.DELETE_CONFIRM')"
      :message="''"
      :message-value="selectedProduct?.name"
      :confirm-text="t('PRODUCTS.DELETE_CONFIRM_YES')"
      :reject-text="t('PRODUCTS.DELETE_CONFIRM_NO')"
    />
  </SettingsLayout>
</template>
