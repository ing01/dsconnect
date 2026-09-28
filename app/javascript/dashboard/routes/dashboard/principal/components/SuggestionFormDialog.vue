<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import SuggestionFileInput from '../../suggestions/components/SuggestionFileInput.vue';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const title = ref('');
const description = ref('');
const files = ref([]);

const open = () => {
  title.value = '';
  description.value = '';
  files.value = [];
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!title.value.trim()) return;
  emit('submit', {
    title: title.value.trim(),
    description: description.value.trim(),
    files: [...files.value],
  });
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('PRINCIPAL.SUGGESTIONS.FORM.TITLE')"
    :description="t('PRINCIPAL.SUGGESTIONS.FORM.DESCRIPTION')"
    :cancel-button-label="t('PRINCIPAL.SUGGESTIONS.FORM.CANCEL')"
    :confirm-button-label="t('PRINCIPAL.SUGGESTIONS.FORM.SUBMIT')"
    :disable-confirm-button="!title.trim()"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4">
      <NextInput
        v-model="title"
        :label="t('PRINCIPAL.SUGGESTIONS.FORM.TITLE_FIELD.LABEL')"
        :placeholder="t('PRINCIPAL.SUGGESTIONS.FORM.TITLE_FIELD.PLACEHOLDER')"
      />
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('PRINCIPAL.SUGGESTIONS.FORM.DESCRIPTION_FIELD.LABEL') }}
        </span>
        <textarea
          v-model="description"
          rows="4"
          class="w-full mb-0"
          :placeholder="t('PRINCIPAL.SUGGESTIONS.FORM.DESCRIPTION_FIELD.PLACEHOLDER')"
        />
      </label>
      <SuggestionFileInput v-model="files" />
    </div>
  </Dialog>
</template>
