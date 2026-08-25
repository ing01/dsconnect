<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketPicker from './TicketPicker.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const parentId = ref(null);

const open = () => {
  parentId.value = props.ticket.parent?.id ?? null;
  dialogRef.value?.open();
};

// `belongs_to :parent` holds one reference, so choosing another REPLACES the
// current one rather than adding to it. Cycles (A -> B -> C -> A) are rejected
// by the model, not just hidden here - the API accepts a parent directly.
const handleConfirm = () => emit('submit', parentId.value);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('TICKET.ACTIONS.PARENT_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.PARENT_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-2 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.ACTIONS.PARENT_DIALOG.LABEL') }}
      </span>
      <TicketPicker
        v-model="parentId"
        :exclude-id="ticket.id"
        :placeholder="t('TICKET.ACTIONS.PICKER.PLACEHOLDER')"
      />
      <p v-if="ticket.parent" class="text-xs text-n-slate-10">
        {{
          t('TICKET.ACTIONS.PARENT_DIALOG.REPLACES', {
            number: ticket.parent.display_id,
          })
        }}
      </p>
    </div>
  </Dialog>
</template>
