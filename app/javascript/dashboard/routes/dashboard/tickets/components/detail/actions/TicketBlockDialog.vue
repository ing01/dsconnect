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

// Ao contrario do cancelamento, aqui o motivo e OBRIGATORIO: ele vira o
// comentario interno que a equipe le para saber o que destravar. Um impedimento
// sem explicacao nao serve a ninguem.
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
    type="edit"
    width="md"
    :title="
      t('TICKET.ACTIONS.BLOCK_DIALOG.TITLE', { number: ticket.display_id })
    "
    :description="t('TICKET.ACTIONS.BLOCK_DIALOG.DESCRIPTION')"
    :cancel-button-label="t('TICKET.ACTIONS.BLOCK_DIALOG.BACK')"
    :confirm-button-label="t('TICKET.ACTIONS.BLOCK_DIALOG.CONFIRM')"
    :disable-confirm-button="!hasReason"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <label class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.ACTIONS.BLOCK_DIALOG.REASON') }}
      </span>
      <textarea
        v-model="reason"
        rows="3"
        class="w-full mb-0"
        :placeholder="t('TICKET.ACTIONS.BLOCK_DIALOG.REASON_PLACEHOLDER')"
      />
      <span class="text-xs text-n-slate-11">
        {{ t('TICKET.ACTIONS.BLOCK_DIALOG.REASON_HINT') }}
      </span>
    </label>
  </Dialog>
</template>
