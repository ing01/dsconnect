<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import TicketPropertyRow from './TicketPropertyRow.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

// The API returns the raw `Channel::` class name; nobody wants to read
// "Channel::WebWidget" in a ticket header.
const CHANNEL_LABELS = {
  [INBOX_TYPES.WEB]: 'Webchat',
  [INBOX_TYPES.FB]: 'Facebook',
  [INBOX_TYPES.TWITTER]: 'X',
  [INBOX_TYPES.TWILIO]: 'SMS',
  [INBOX_TYPES.WHATSAPP]: 'WhatsApp',
  [INBOX_TYPES.API]: 'API',
  [INBOX_TYPES.EMAIL]: 'E-mail',
  [INBOX_TYPES.TELEGRAM]: 'Telegram',
  [INBOX_TYPES.LINE]: 'LINE',
  [INBOX_TYPES.SMS]: 'SMS',
  [INBOX_TYPES.INSTAGRAM]: 'Instagram',
  [INBOX_TYPES.TIKTOK]: 'TikTok',
};

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const conversation = computed(() => (props.ticket.conversations || [])[0]);

// A ticket opened straight from the Kanban has no conversation, so its origin
// is simply manual rather than a channel. The inbox name is preferred when set,
// since that is what agents actually call it.
const origin = computed(() => {
  if (!conversation.value) return t('TICKET.DETAIL.ORIGIN.MANUAL');

  const channel = conversation.value.channel;
  return (
    conversation.value.inbox_name || CHANNEL_LABELS[channel] || channel || '—'
  );
});

const createdAt = computed(() =>
  props.ticket.created_at
    ? new Date(props.ticket.created_at * 1000).toLocaleString()
    : '—'
);

// The dashboard resolves conversations by `display_id`, not the primary key -
// navigating with `id` lands on someone else's conversation.
const openConversation = () => {
  if (!conversation.value) return;
  router.push(
    frontendURL(
      `accounts/${route.params.accountId}/conversations/${conversation.value.display_id}`
    )
  );
};
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.ORIGIN.TITLE') }}
    </h2>

    <TicketPropertyRow :label="t('TICKET.DETAIL.ORIGIN.CHANNEL')">
      <span class="text-sm text-n-slate-12 truncate" :title="origin">
        {{ origin }}
      </span>
    </TicketPropertyRow>

    <TicketPropertyRow :label="t('TICKET.DETAIL.ORIGIN.CREATED_AT')">
      <span class="text-sm text-n-slate-12">{{ createdAt }}</span>
    </TicketPropertyRow>

    <TicketPropertyRow
      v-if="ticket.created_by"
      :label="t('TICKET.DETAIL.ORIGIN.CREATED_BY')"
    >
      <span class="text-sm text-n-slate-12 truncate">
        {{ ticket.created_by.name }}
      </span>
    </TicketPropertyRow>

    <Button
      v-if="conversation"
      variant="faded"
      color="slate"
      size="sm"
      icon="i-lucide-messages-square"
      class="w-full"
      :label="t('TICKET.DETAIL.ORIGIN.OPEN_CONVERSATION')"
      @click="openConversation"
    />
  </section>
</template>
