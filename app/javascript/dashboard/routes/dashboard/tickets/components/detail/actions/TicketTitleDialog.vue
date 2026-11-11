<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { stripModule } from '../../../helpers/titleModule';
import TicketModuleSelect from '../../TicketModuleSelect.vue';

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
// Com o modulo no comeco, o que sobra tambem precisa ter texto.
const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');
const isValid = computed(
  () =>
    stripModule(
      title.value,
      catalogs.value.map(item => item.name)
    ).trim().length > 0
);

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
    <div class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.ACTIONS.TITLE_DIALOG.LABEL') }}
        <span class="text-n-ruby-11">*</span>
      </span>
      <!-- O modulo do sistema vai para o comeco do titulo, no formato [Modulo]. -->
      <TicketModuleSelect v-model="title" class="sm:!w-full" />
      <input
        v-model="title"
        type="text"
        class="w-full mb-0"
        :placeholder="t('TICKET.ACTIONS.TITLE_DIALOG.LABEL')"
        @keyup.enter="handleConfirm"
      />
    </div>
  </Dialog>
</template>
