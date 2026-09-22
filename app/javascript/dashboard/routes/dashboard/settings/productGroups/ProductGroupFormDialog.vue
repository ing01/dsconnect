<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const dialogRef = ref(null);
const editingId = ref(null);

const form = reactive({
  name: '',
  totalValueMode: 'auto',
  totalValue: '',
});

const isEditing = computed(() => Boolean(editingId.value));
const isFormInvalid = computed(() => !form.name.trim());

const resetForm = () => {
  editingId.value = null;
  form.name = '';
  form.totalValueMode = 'auto';
  form.totalValue = '';
};

const open = (productGroup = null) => {
  if (productGroup) {
    editingId.value = productGroup.id;
    form.name = productGroup.name || '';
    form.totalValueMode = productGroup.totalValueMode || 'auto';
    form.totalValue = productGroup.totalValue ?? '';
  } else {
    resetForm();
  }
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (isFormInvalid.value) return;

  emit('submit', {
    id: editingId.value,
    name: form.name.trim(),
    totalValueMode: form.totalValueMode,
    totalValue: form.totalValueMode === 'manual' ? form.totalValue : null,
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
        {{ isEditing ? t('PRODUCT_GROUPS.FORM.EDIT_TITLE') : t('PRODUCT_GROUPS.FORM.CREATE_TITLE') }}
      </span>

      <Input
        v-model="form.name"
        :label="t('PRODUCT_GROUPS.FORM.NAME')"
        :disabled="isLoading"
        custom-input-class="h-9"
        autofocus
      />

      <div class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak bg-n-alpha-1">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-12">{{ t('PRODUCT_GROUPS.FORM.VALUE_LABEL') }}</span>
          <label class="flex items-center gap-1 text-xs text-n-slate-11">
            <input
              type="checkbox"
              :checked="form.totalValueMode === 'manual'"
              @change="form.totalValueMode = $event.target.checked ? 'manual' : 'auto'"
            />
            {{ t('PRODUCT_GROUPS.FORM.MANUAL_TOGGLE') }}
          </label>
        </div>
        <Input
          v-if="form.totalValueMode === 'manual'"
          v-model="form.totalValue"
          type="number"
          custom-input-class="h-9"
        />
        <p v-else class="mb-0 text-xs text-n-slate-11">
          {{ t('PRODUCT_GROUPS.FORM.AUTO_HELP') }}
        </p>
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
          :label="t('PRODUCT_GROUPS.FORM.SAVE')"
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
