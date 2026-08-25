<script setup>
import { useI18n } from 'vue-i18n';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';

const { t } = useI18n();
</script>

<template>
  <!-- SLA exists in this product only for Conversations, and is enterprise-only.
       Nothing is computed for tickets yet, so the panel states that plainly
       rather than showing invented deadlines. -->
  <Accordion :title="t('TICKET.DETAIL.SLA.TITLE')">
    <p class="pt-2 text-sm text-n-slate-10">
      {{ t('TICKET.DETAIL.SLA.EMPTY') }}
    </p>
  </Accordion>
</template>
