<script setup>
import { computed, ref } from 'vue';
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
const sourceId = ref(null);

// The ticket in view is always the survivor; the picked one is the one closed.
const subject = computed(() =>
  [props.ticket.company_name, props.ticket.contact?.name, props.ticket.title]
    .filter(Boolean)
    .map(part => `[${part}]`)
    .join(' | ')
);

const open = () => {
  sourceId.value = null;
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!sourceId.value) return;
  emit('submit', sourceId.value);
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('TICKET.ACTIONS.MERGE_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.MERGE_DIALOG.CONFIRM')"
    :disable-confirm-button="!sourceId"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <div class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.MERGE_DIALOG.KEPT') }}
        </span>
        <span class="text-sm break-words text-n-slate-11">
          <span class="text-n-slate-10">#{{ ticket.display_id }}</span>
          {{ subject }}
        </span>
      </div>

      <div class="h-px bg-n-weak" />

      <div class="flex flex-col gap-2 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.MERGE_DIALOG.TO_CLOSE') }}
        </span>
        <!-- Only open tickets: closing an already-closed ticket "into" another
             changes nothing and the server rejects re-merging one. -->
        <TicketPicker
          v-model="sourceId"
          open-only
          :exclude-id="ticket.id"
          :placeholder="t('TICKET.ACTIONS.MERGE_DIALOG.PLACEHOLDER')"
        />
        <p class="text-xs text-n-slate-10">
          {{ t('TICKET.ACTIONS.MERGE_DIALOG.HINT') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
