<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  childrenCount: { type: Number, default: 0 },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
// Keeping the children (just unlinking them) is the safer default - deleting
// them is something the admin has to opt into on purpose every time.
const keepChildren = ref(true);

const hasChildren = computed(() => props.childrenCount > 0);

const open = () => {
  keepChildren.value = true;
  dialogRef.value?.open();
};

const handleConfirm = () => emit('submit', hasChildren.value && !keepChildren.value);

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="md"
    :title="
      t('TICKET.ACTIONS.DELETE_DIALOG.TITLE', { number: ticket.display_id })
    "
    :description="t('TICKET.ACTIONS.DELETE_DIALOG.DESCRIPTION')"
    :cancel-button-label="t('TICKET.ACTIONS.DELETE_DIALOG.BACK')"
    :confirm-button-label="t('TICKET.ACTIONS.DELETE_DIALOG.CONFIRM')"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div v-if="hasChildren" class="flex flex-col gap-3">
      <p class="text-sm text-n-slate-11 mb-0">
        {{
          t('TICKET.ACTIONS.DELETE_DIALOG.CHILDREN_WARNING', {
            n: childrenCount,
          })
        }}
      </p>
      <RadioCard
        id="keep-children"
        name="delete-children-choice"
        :label="t('TICKET.ACTIONS.DELETE_DIALOG.KEEP_CHILDREN.LABEL')"
        :description="t('TICKET.ACTIONS.DELETE_DIALOG.KEEP_CHILDREN.DESCRIPTION')"
        :is-active="keepChildren"
        @select="keepChildren = true"
      />
      <RadioCard
        id="delete-children"
        name="delete-children-choice"
        :label="t('TICKET.ACTIONS.DELETE_DIALOG.DELETE_CHILDREN.LABEL')"
        :description="t('TICKET.ACTIONS.DELETE_DIALOG.DELETE_CHILDREN.DESCRIPTION')"
        :is-active="!keepChildren"
        @select="keepChildren = false"
      />
    </div>
  </Dialog>
</template>
