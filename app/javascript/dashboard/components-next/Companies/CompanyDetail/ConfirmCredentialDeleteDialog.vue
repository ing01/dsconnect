<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['confirm']);

const { t } = useI18n();
const dialogRef = ref(null);

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="t('COMPANIES.DETAIL.CREDENTIALS.DELETE.TITLE')"
    :description="t('COMPANIES.DETAIL.CREDENTIALS.DELETE.DESCRIPTION')"
    :confirm-button-label="t('COMPANIES.DETAIL.CREDENTIALS.DELETE.CONFIRM')"
    :is-loading="isLoading"
    @confirm="emit('confirm')"
  />
</template>
