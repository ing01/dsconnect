<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
</script>

<template>
  <!-- Structure only: this has no backing model yet, so the panel says so
       rather than showing placeholder items that look real. -->
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.CHECKLISTS.TITLE') }}
    </h2>
    <p class="flex items-center gap-2 text-sm text-n-slate-10">
      <Icon icon="i-lucide-info" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.CHECKLISTS.EMPTY') }}
    </p>
  </section>
</template>
