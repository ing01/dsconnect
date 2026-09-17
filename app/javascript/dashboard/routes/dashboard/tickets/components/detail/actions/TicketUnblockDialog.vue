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

// Retirar o impedimento nao pede motivo: o que interessa ao historico e quem
// retirou e quando, e isso o servidor registra sozinho. Pedir um texto aqui so
// criaria atrito para desfazer algo que ja esta explicado no comentario que
// originou o impedimento.
const handleConfirm = () => emit('submit');

defineExpose({
  open: () => dialogRef.value?.open(),
  close: () => dialogRef.value?.close(),
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="md"
    :title="
      t('TICKET.ACTIONS.UNBLOCK_DIALOG.TITLE', { number: ticket.display_id })
    "
    :description="t('TICKET.ACTIONS.UNBLOCK_DIALOG.DESCRIPTION')"
    :cancel-button-label="t('TICKET.ACTIONS.UNBLOCK_DIALOG.BACK')"
    :confirm-button-label="t('TICKET.ACTIONS.UNBLOCK_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div
      v-if="ticket.blocked_reason"
      class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-2"
    >
      <span class="text-xs font-medium uppercase text-n-slate-11">
        {{ t('TICKET.ACTIONS.UNBLOCK_DIALOG.CURRENT_REASON') }}
      </span>
      <p class="m-0 text-sm whitespace-pre-line text-n-slate-12">
        {{ ticket.blocked_reason }}
      </p>
    </div>
  </Dialog>
</template>
