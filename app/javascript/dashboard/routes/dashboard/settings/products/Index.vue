<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useProductsStore } from 'dashboard/stores/products';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const productsStore = useProductsStore();

const newProductName = ref('');
const editingId = ref(null);
const editingName = ref('');
const selectedProduct = ref(null);
const showDeleteConfirmationPopup = ref(false);

const products = computed(() => productsStore.getProducts);
const uiFlags = computed(() => productsStore.uiFlags);

const tableHeaders = computed(() => [
  t('PRODUCTS.HEADER'),
  '',
]);

const createProduct = async () => {
  const name = newProductName.value.trim();
  if (!name) return;
  try {
    await productsStore.create(name);
    newProductName.value = '';
    useAlert(t('PRODUCTS.MESSAGES.CREATE_SUCCESS'));
  } catch {
    useAlert(t('PRODUCTS.MESSAGES.CREATE_ERROR'));
  }
};

const startEditing = product => {
  editingId.value = product.id;
  editingName.value = product.name;
};

const cancelEditing = () => {
  editingId.value = null;
  editingName.value = '';
};

const saveEditing = async product => {
  const name = editingName.value.trim();
  if (!name || name === product.name) {
    cancelEditing();
    return;
  }
  try {
    await productsStore.update(product.id, name);
    useAlert(t('PRODUCTS.MESSAGES.UPDATE_SUCCESS'));
  } catch {
    useAlert(t('PRODUCTS.MESSAGES.UPDATE_ERROR'));
  } finally {
    cancelEditing();
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
          <div class="flex items-center gap-2">
            <Input
              v-model="newProductName"
              :placeholder="t('PRODUCTS.ADD_PLACEHOLDER')"
              custom-input-class="h-8 !pt-1 !pb-1"
              @keyup.enter="createProduct"
            />
            <Button
              :label="t('PRODUCTS.ADD_BUTTON')"
              size="sm"
              :is-loading="uiFlags.isCreating"
              :disabled="!newProductName.trim()"
              @click="createProduct"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable :headers="tableHeaders" :items="products">
        <template #row="{ items }">
          <BaseTableRow v-for="product in items" :key="product.id" :item="product">
            <template #default>
              <BaseTableCell>
                <Input
                  v-if="editingId === product.id"
                  v-model="editingName"
                  custom-input-class="h-8 !pt-1 !pb-1"
                  autofocus
                  @keyup.enter="saveEditing(product)"
                  @blur="saveEditing(product)"
                  @keyup.esc="cancelEditing"
                />
                <span v-else class="text-body-main text-n-slate-12">
                  {{ product.name }}
                </span>
              </BaseTableCell>
              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="startEditing(product)"
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
