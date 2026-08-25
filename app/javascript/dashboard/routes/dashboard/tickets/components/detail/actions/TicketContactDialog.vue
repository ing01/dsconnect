<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketContactSelect from '../../TicketContactSelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const contactId = ref(null);

const open = () => {
  contactId.value = props.ticket.contact_id ?? props.ticket.contact?.id ?? null;
  dialogRef.value?.open();
};

// Sends the id: the ticket references the Contact record, so no name or e-mail
// is duplicated onto the ticket.
const handleConfirm = () => emit('submit', contactId.value || null);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('TICKET.ACTIONS.CONTACT_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.CONTACT_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-2 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.REQUESTER.CONTACT') }}
      </span>
      <TicketContactSelect
        v-model="contactId"
        :company-id="ticket.company_id"
        :initial-name="ticket.contact?.name || ''"
      />
      <!-- The Solicitante comes from the Empresa's own contacts, so without an
           Empresa there is nothing to choose from. -->
      <p v-if="!ticket.company_id" class="text-xs text-n-slate-10">
        {{ t('TICKET.ACTIONS.CONTACT_DIALOG.NEEDS_COMPANY') }}
      </p>
    </div>
  </Dialog>
</template>
