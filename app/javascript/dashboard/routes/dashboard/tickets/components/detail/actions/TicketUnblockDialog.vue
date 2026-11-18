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

// Quem retirou e quando o servidor registra sozinho. A RESOLUCAO - como o impedimento
// foi resolvido - e' opcional (nao trava quem so' precisa liberar), mas quando vem
// fica nos comentarios e no historico do ticket e do pai que sai junto com ele.
const resolution = ref('');

const handleConfirm = () => {
  emit('submit', resolution.value.trim());
  resolution.value = '';
};

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
    <label class="flex flex-col gap-1 mt-3">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('TICKET.ACTIONS.UNBLOCK_DIALOG.RESOLUTION') }}
      </span>
      <textarea
        v-model="resolution"
        rows="3"
        class="w-full mb-0"
        :placeholder="t('TICKET.ACTIONS.UNBLOCK_DIALOG.RESOLUTION_PLACEHOLDER')"
        data-testid="unblock-resolution"
      />
      <span class="text-xs text-n-slate-10">
        {{ t('TICKET.ACTIONS.UNBLOCK_DIALOG.RESOLUTION_HINT') }}
      </span>
    </label>
  </Dialog>
</template>
