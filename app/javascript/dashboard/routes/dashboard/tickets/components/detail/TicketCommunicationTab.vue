<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketComments from '../TicketComments.vue';

defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const formatDateTime = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '';

// Navigates by `display_id`: the dashboard route and the conversations API both
// resolve on it, so using the primary key opens the wrong conversation.
const openConversation = conversation => {
  router.push(
    frontendURL(
      `accounts/${route.params.accountId}/conversations/${conversation.display_id}`
    )
  );
};
</script>

<template>
  <div class="flex flex-col gap-4 w-full min-w-0">
    <section
      class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
    >
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.LINKED_CONVERSATIONS') }}
      </h2>

      <p
        v-if="!(ticket.conversations || []).length"
        class="text-sm text-n-slate-10"
      >
        {{ t('TICKET.DETAIL.NO_CONVERSATIONS') }}
      </p>

      <ul v-else class="flex flex-col gap-1">
        <li v-for="conversation in ticket.conversations" :key="conversation.id">
          <button
            type="button"
            class="flex flex-col w-full gap-1 px-2 py-2 text-left rounded-lg hover:bg-n-alpha-2 transition-colors min-w-0"
            @click="openConversation(conversation)"
          >
            <span class="flex items-center gap-2 min-w-0">
              <Icon
                icon="i-lucide-messages-square"
                class="size-4 text-n-slate-11 flex-shrink-0"
              />
              <span class="text-sm text-n-slate-12 truncate">
                #{{ conversation.display_id }}
                <template v-if="conversation.contact_name">
                  — {{ conversation.contact_name }}
                </template>
              </span>
            </span>
            <span
              class="flex flex-wrap items-center gap-2 text-xs text-n-slate-10"
            >
              <span v-if="conversation.inbox_name">
                {{ conversation.inbox_name }}
              </span>
              <span v-if="conversation.status">{{ conversation.status }}</span>
              <span v-if="conversation.last_activity_at">
                {{ formatDateTime(conversation.last_activity_at) }}
              </span>
            </span>
          </button>
        </li>
      </ul>
    </section>

    <!-- Internal comments stay visibly separate from the customer-facing
         conversation above: different audience, different place. -->
    <section class="rounded-xl border border-n-weak p-4 min-w-0">
      <TicketComments :ticket-id="ticket.id" />
    </section>
  </div>
</template>
