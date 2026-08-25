<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const reason = ref('');

const open = () => {
  reason.value = '';
  dialogRef.value?.open();
};

// The reason is optional: requiring one would block the common case of an
// obvious cancellation, and the activity records who and when regardless.
// Cancelling never deletes the ticket - it is a terminal status, so the record,
// its history and its attachments all stay readable.
const handleConfirm = () => emit('submit', reason.value.trim() || null);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="md"
    :title="
      t('TICKET.ACTIONS.CANCEL_DIALOG.TITLE', { number: ticket.display_id })
    "
    :description="t('TICKET.ACTIONS.CANCEL_DIALOG.DESCRIPTION')"
    :cancel-button-label="t('TICKET.ACTIONS.CANCEL_DIALOG.BACK')"
    :confirm-button-label="t('TICKET.ACTIONS.CANCEL_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.ACTIONS.CANCEL_DIALOG.REASON') }}
      </span>
      <textarea
        v-model="reason"
        rows="3"
        class="w-full mb-0"
        :placeholder="t('TICKET.ACTIONS.CANCEL_DIALOG.REASON_PLACEHOLDER')"
      />
    </label>
  </Dialog>
</template>
