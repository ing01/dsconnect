<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketCompanySelect from '../../TicketCompanySelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const companyId = ref(null);

const open = () => {
  companyId.value = props.ticket.company_id ?? null;
  dialogRef.value?.open();
};

// Sends the id, never the name: the ticket references the Company record, so
// nothing is duplicated as loose text.
//
// The Solicitante belongs to the Empresa, so moving the ticket to a company the
// current requester is not part of clears it in the SAME save - the backend
// rejects the mismatched pair, and leaving it to a second request would surface
// that as an error. The contact payload carries its own `company_id`, so this
// needs no extra round-trip.
const handleConfirm = () => {
  const target = companyId.value || null;
  const contactCompanyId = props.ticket.contact?.company_id ?? null;
  const keepsContact =
    !props.ticket.contact || String(contactCompanyId) === String(target);

  emit('submit', { companyId: target, clearContact: !keepsContact });
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('TICKET.ACTIONS.COMPANY_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.COMPANY_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-2 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.COMPANY.LABEL') }}
      </span>
      <!-- The same searchable selector the ticket form uses, so it searches
           every Empresa in the account rather than a preloaded slice. -->
      <TicketCompanySelect
        v-model="companyId"
        :initial-name="ticket.company_name || ''"
      />
    </div>
  </Dialog>
</template>
