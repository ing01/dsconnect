<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const title = ref('');

// Only the title. The ticket number is not editable and is not part of this
// form - it identifies the ticket.
const isValid = computed(() => title.value.trim().length > 0);

const open = () => {
  title.value = props.ticket.title || '';
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!isValid.value) return;
  emit('submit', title.value.trim());
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('TICKET.ACTIONS.TITLE_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.TITLE_DIALOG.CONFIRM')"
    :disable-confirm-button="!isValid"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.ACTIONS.TITLE_DIALOG.LABEL') }}
        <span class="text-n-ruby-11">*</span>
      </span>
      <input
        v-model="title"
        type="text"
        class="w-full mb-0"
        :placeholder="t('TICKET.ACTIONS.TITLE_DIALOG.LABEL')"
        @keyup.enter="handleConfirm"
      />
    </label>
  </Dialog>
</template>
