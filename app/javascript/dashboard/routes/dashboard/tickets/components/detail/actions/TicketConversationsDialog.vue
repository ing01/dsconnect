<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

// The API returns the raw `Channel::` class name; nobody wants to read
// "Channel::WebWidget" in a list of conversations.
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

const dialogRef = ref(null);

// A ticket can link any number of Conversations, so this is always a list -
// even with one, which keeps the behaviour consistent.
const conversations = computed(() =>
  [...(props.ticket.conversations || [])].sort(
    (a, b) => (b.last_activity_at || 0) - (a.last_activity_at || 0)
  )
);

const channelLabel = conversation =>
  CHANNEL_LABELS[conversation.channel] || conversation.channel || '—';

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleString() : '—';

// The dashboard router and the conversations API both resolve on `display_id`,
// not the primary key - navigating with `id` opens someone else's conversation.
const openConversation = conversation => {
  dialogRef.value?.close();
  router.push(
    frontendURL(
      `accounts/${route.params.accountId}/conversations/${conversation.display_id}`
    )
  );
};

const STATUS_COLORS = { open: 'blue', resolved: 'teal', pending: 'amber' };
const statusColor = status => STATUS_COLORS[status] || 'slate';

defineExpose({
  open: () => dialogRef.value?.open(),
  close: () => dialogRef.value?.close(),
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('TICKET.ACTIONS.CONVERSATIONS_DIALOG.TITLE')"
    :show-confirm-button="false"
    :cancel-button-label="t('TICKET.ACTIONS.CLOSE_DIALOG')"
  >
    <!-- No conversations is a normal state for a ticket opened straight from
         the Kanban, so it says so instead of rendering an empty box. -->
    <p
      v-if="!conversations.length"
      class="flex items-center gap-2 py-4 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-message-square-off" class="flex-shrink-0 size-4" />
      {{ t('TICKET.ACTIONS.CONVERSATIONS_DIALOG.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-2 min-w-0 max-h-[60vh] overflow-y-auto">
      <li
        v-for="conversation in conversations"
        :key="conversation.id"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak min-w-0 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="flex flex-col gap-1 min-w-0">
          <div class="flex flex-wrap items-center gap-2 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ channelLabel(conversation) }}
            </span>
            <WootLabel
              v-if="conversation.status"
              :label="conversation.status"
              :color="statusColor(conversation.status)"
              compact
            />
            <span class="text-xs text-n-slate-10">
              #{{ conversation.display_id }}
            </span>
          </div>

          <span class="text-sm truncate text-n-slate-11">
            {{
              [conversation.contact_name, conversation.company_name]
                .filter(Boolean)
                .join(' - ') || t('TICKET.ACTIONS.CONVERSATIONS_DIALOG.NO_CONTACT')
            }}
          </span>

          <span v-if="conversation.inbox_name" class="text-xs truncate text-n-slate-10">
            {{ conversation.inbox_name }}
          </span>

          <span v-if="conversation.last_message" class="text-xs truncate text-n-slate-10">
            {{ conversation.last_message }}
          </span>

          <span class="text-xs text-n-slate-10">
            {{ t('TICKET.ACTIONS.CONVERSATIONS_DIALOG.LAST_ACTIVITY') }}:
            {{ formatDate(conversation.last_activity_at) }}
          </span>
        </div>

        <Button
          variant="faded"
          color="slate"
          size="sm"
          class="flex-shrink-0 w-full sm:w-auto"
          :label="t('TICKET.ACTIONS.CONVERSATIONS_DIALOG.OPEN')"
          @click="openConversation(conversation)"
        />
      </li>
    </ul>
  </Dialog>
</template>
