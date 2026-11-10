<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  tickets: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const route = useRoute();

// A rota do ticket usa o id do banco (`ticket.id`), nao o numero exibido.
const ticketUrl = ticket =>
  frontendURL(`accounts/${route.params.accountId}/tickets/${ticket.id}`);

const priorityColor = priority =>
  ({
    urgent: 'bg-n-ruby-9',
    high: 'bg-n-amber-9',
    medium: 'bg-n-blue-9',
    low: 'bg-n-slate-9',
  })[priority] || 'bg-n-slate-9';
</script>

<template>
  <div v-if="isLoading" class="flex items-center justify-center py-10 text-n-slate-11">
    <Spinner />
  </div>

  <div v-else-if="tickets.length > 0" class="flex flex-col gap-2">
    <router-link
      v-for="ticket in tickets"
      :key="ticket.id"
      :to="ticketUrl(ticket)"
      class="flex items-center justify-between gap-3 px-3 py-2.5 rounded-xl border border-n-weak hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
    >
      <div class="flex items-center gap-2.5 min-w-0">
        <span
          class="flex-shrink-0 w-2 h-2 rounded-full"
          :class="priorityColor(ticket.priority)"
        />
        <span
          v-if="ticket.displayId"
          class="flex-shrink-0 text-xs tabular-nums text-n-slate-11"
        >
          #{{ ticket.displayId }}
        </span>
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ ticket.title }}
        </span>
      </div>
      <span
        v-if="ticket.conversationIds?.length"
        class="flex-shrink-0 text-xs text-n-slate-11"
      >
        {{ t('TICKET.CARD.CONVERSATIONS_LINKED', ticket.conversationIds.length) }}
      </span>
    </router-link>
  </div>

  <p
    v-else
    class="py-8 px-4 text-sm text-center rounded-xl border border-dashed border-n-strong text-n-slate-11"
  >
    {{ t('COMPANIES.DETAIL.TICKETS.EMPTY') }}
  </p>
</template>
