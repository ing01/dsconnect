<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// Avisa que o texto do campo veio de antes, para ninguem enviar sem perceber.
const emit = defineEmits(['discard']);

const { t } = useI18n();
</script>

<template>
  <p
    class="flex flex-wrap items-center gap-2 m-0 text-xs text-n-slate-11"
    role="status"
    data-testid="draft-notice"
  >
    <Icon icon="i-lucide-history" class="flex-shrink-0 size-3.5" />
    {{ t('TEXT_DRAFT.RESTORED') }}
    <button
      type="button"
      class="font-medium text-n-ruby-11 hover:underline"
      data-testid="draft-discard"
      @click="emit('discard')"
    >
      {{ t('TEXT_DRAFT.DISCARD') }}
    </button>
  </p>
</template>
