<script setup>
import { computed, ref } from 'vue';
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

// O motivo e' o unico dado pedido, e e' obrigatorio: cancelar descarta o
// chamado, e quem ler o historico depois precisa saber por que.
const hasReason = computed(() => reason.value.trim().length > 0);

const open = () => {
  reason.value = '';
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!hasReason.value) return;

  emit('submit', reason.value.trim());
};

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
    :disable-confirm-button="!hasReason"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.ACTIONS.CANCEL_DIALOG.REASON') }}
        <span class="text-n-ruby-11">*</span>
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
