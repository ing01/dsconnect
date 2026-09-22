<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useProductGroupsStore } from 'dashboard/stores/productGroups';

const props = defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const productGroupsStore = useProductGroupsStore();
const dialogRef = ref(null);
const editingId = ref(null);
const newGroupName = ref('');

const productGroups = computed(() => productGroupsStore.getProductGroups);

const form = reactive({
  name: '',
  value: '',
  productGroupId: '',
});

const isEditing = computed(() => Boolean(editingId.value));
const isFormInvalid = computed(() => !form.name.trim() || !form.productGroupId);

const resetForm = () => {
  editingId.value = null;
  form.name = '';
  form.value = '';
  form.productGroupId = '';
  newGroupName.value = '';
};

const open = (product = null) => {
  productGroupsStore.get();
  if (product) {
    editingId.value = product.id;
    form.name = product.name || '';
    form.value = product.value ?? '';
    form.productGroupId = product.productGroupId || '';
  } else {
    resetForm();
  }
  dialogRef.value?.open();
};

const handleCreateGroup = async () => {
  const name = newGroupName.value.trim();
  if (!name) return;
  try {
    const created = await productGroupsStore.create({ name });
    form.productGroupId = created.id;
    newGroupName.value = '';
  } catch {
    useAlert(t('PRODUCT_GROUPS.MESSAGES.CREATE_ERROR'));
  }
};

const handleConfirm = () => {
  if (isFormInvalid.value) return;

  emit('submit', {
    id: editingId.value,
    name: form.name.trim(),
    value: form.value === '' ? null : form.value,
    productGroupId: form.productGroupId,
  });
};

const closeDialog = () => dialogRef.value?.close();
const onSuccess = () => {
  resetForm();
  closeDialog();
};

defineExpose({ dialogRef, onSuccess, open });
</script>

<template>
  <Dialog ref="dialogRef" width="md" @confirm="handleConfirm" @close="resetForm">
    <div class="flex flex-col gap-4">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ isEditing ? t('PRODUCTS.FORM.EDIT_TITLE') : t('PRODUCTS.FORM.CREATE_TITLE') }}
      </span>

      <Input
        v-model="form.name"
        :label="t('PRODUCTS.FORM.NAME')"
        :disabled="isLoading"
        custom-input-class="h-9"
        autofocus
      />

      <Input
        v-model="form.value"
        type="number"
        :label="t('PRODUCTS.FORM.VALUE')"
        :disabled="isLoading"
        custom-input-class="h-9"
      />

      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">{{ t('PRODUCTS.FORM.GROUP') }}</label>
        <select
          v-model="form.productGroupId"
          class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
        >
          <option value="" disabled>{{ t('PRODUCTS.FORM.GROUP_SELECT_PLACEHOLDER') }}</option>
          <option v-for="group in productGroups" :key="group.id" :value="group.id">{{ group.name }}</option>
        </select>
        <div class="flex items-center gap-2 mt-1">
          <input
            v-model="newGroupName"
            type="text"
            :placeholder="t('PRODUCTS.FORM.NEW_GROUP_PLACEHOLDER')"
            class="h-8 px-2 text-xs rounded border border-n-weak bg-n-solid-1 text-n-slate-12 focus:border-n-brand focus:outline-none"
            @keyup.enter="handleCreateGroup"
          />
          <Button
            :label="t('PRODUCTS.FORM.NEW_GROUP_BUTTON')"
            size="sm"
            variant="faded"
            slate
            :disabled="!newGroupName.trim()"
            @click="handleCreateGroup"
          />
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="link"
          type="reset"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click="closeDialog"
        />
        <Button
          :label="t('PRODUCTS.FORM.SAVE')"
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
