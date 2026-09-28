<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, parseISO } from 'date-fns';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['delete']);

const { t } = useI18n();

const dialogRef = ref(null);
const suggestion = ref(null);

const open = record => {
  suggestion.value = record;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const dateLabel = computed(() =>
  suggestion.value?.created_at
    ? format(parseISO(suggestion.value.created_at), 'dd/MM/yyyy HH:mm')
    : ''
);

const handleDelete = () => {
  emit('delete', suggestion.value);
  close();
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="suggestion?.title"
    :show-confirm-button="false"
    :cancel-button-label="t('SUGGESTIONS.DETAIL.CLOSE')"
  >
    <div v-if="suggestion" class="flex flex-col gap-3">
      <p class="text-xs text-n-slate-11 mb-0">
        {{
          t('SUGGESTIONS.DETAIL.SUBMITTED_BY', {
            name: suggestion.user_name,
            date: dateLabel,
          })
        }}
      </p>
      <p class="text-sm text-n-slate-12 whitespace-pre-wrap mb-0">
        {{ suggestion.description || t('SUGGESTIONS.DETAIL.NO_DESCRIPTION') }}
      </p>
      <div v-if="props.canManage" class="flex justify-end pt-2 border-t border-n-weak">
        <Button
          ruby
          faded
          size="sm"
          icon="i-lucide-trash-2"
          :label="t('SUGGESTIONS.DETAIL.DELETE')"
          @click="handleDelete"
        />
      </div>
    </div>
  </Dialog>
</template>
