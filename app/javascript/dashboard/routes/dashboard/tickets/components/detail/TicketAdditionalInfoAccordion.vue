<script setup>
import { useI18n } from 'vue-i18n';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import TicketPropertyRow from './TicketPropertyRow.vue';

defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();

const formatDateTime = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '—';
</script>

<template>
  <Accordion :title="t('TICKET.DETAIL.ADDITIONAL.TITLE')">
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
      <TicketPropertyRow :label="t('TICKET.LIST.COLUMNS.ID')">
        <span class="text-sm text-n-slate-12">#{{ ticket.display_id }}</span>
      </TicketPropertyRow>
      <TicketPropertyRow :label="t('TICKET.DETAIL.ADDITIONAL.CREATED_AT')">
        <span class="text-sm text-n-slate-12">
          {{ formatDateTime(ticket.created_at) }}
        </span>
      </TicketPropertyRow>
      <TicketPropertyRow :label="t('TICKET.DETAIL.ADDITIONAL.UPDATED_AT')">
        <span class="text-sm text-n-slate-12">
          {{ formatDateTime(ticket.updated_at) }}
        </span>
      </TicketPropertyRow>
      <TicketPropertyRow
        v-if="ticket.resolved_at"
        :label="t('TICKET.DETAIL.ADDITIONAL.RESOLVED_AT')"
      >
        <span class="text-sm text-n-slate-12">
          {{ formatDateTime(ticket.resolved_at) }}
        </span>
      </TicketPropertyRow>
      <TicketPropertyRow
        v-if="ticket.closed_at"
        :label="t('TICKET.DETAIL.ADDITIONAL.CLOSED_AT')"
      >
        <span class="text-sm text-n-slate-12">
          {{ formatDateTime(ticket.closed_at) }}
        </span>
      </TicketPropertyRow>
    </div>
  </Accordion>
</template>
