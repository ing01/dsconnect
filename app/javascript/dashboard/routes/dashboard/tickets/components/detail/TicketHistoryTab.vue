<script setup>
import { useI18n } from 'vue-i18n';
import TicketActivityTimeline from '../TicketActivityTimeline.vue';

defineProps({
  ticketId: { type: [Number, String], required: true },
});

const { t } = useI18n();
</script>

<template>
  <!-- Thin wrapper over the existing timeline, which already renders the real
       activity log for all twelve activity types. -->
  <section class="rounded-xl border border-n-weak p-4 min-w-0">
    <h2 class="mb-3 text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.TAB_HISTORY') }}
    </h2>
    <TicketActivityTimeline :ticket-id="ticketId" />
  </section>
</template>
