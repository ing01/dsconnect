<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { humanizeRouteName, screenLabelKey } from './screenLabel';

const props = defineProps({
  thread: {
    type: Object,
    required: true,
  },
});

const route = useRoute();
const { t } = useI18n();

const MAX_TITLE = 40;
const shorten = text =>
  text && text.length > MAX_TITLE ? `${text.slice(0, MAX_TITLE)}…` : text;

// De onde o chat com o DueBot foi aberto, e QUAL: a conversa (numero e contato),
// o ticket (numero e titulo) ou a tela. Conversa e ticket levam um link para
// entrar e ver do que se tratava; a tela e' so' informativa.
const origin = computed(() => {
  const {
    conversation_display_id: conversationId,
    conversation,
    ticket,
    screen,
  } = props.thread;
  const accountId = route?.params?.accountId;

  if (ticket?.id) {
    return {
      icon: 'i-lucide-ticket',
      text: t('CAPTAIN.COPILOT.HISTORY.ORIGIN_TICKET', {
        id: ticket.display_id || ticket.id,
        title: shorten(ticket.title) || '',
      }).trim(),
      to: frontendURL(`accounts/${accountId}/tickets/${ticket.id}`),
    };
  }
  if (conversationId) {
    return {
      icon: 'i-lucide-messages-square',
      text: t('CAPTAIN.COPILOT.HISTORY.ORIGIN_CONVERSATION', {
        id: conversationId,
        contact: shorten(conversation?.contact_name) || '',
      }).trim(),
      to: frontendURL(`accounts/${accountId}/conversations/${conversationId}`),
    };
  }
  if (screen) {
    const key = screenLabelKey(screen);
    return {
      icon: 'i-lucide-layout-dashboard',
      text: t('CAPTAIN.COPILOT.HISTORY.ORIGIN_SCREEN', {
        screen: key ? t(key) : humanizeRouteName(screen),
      }),
      to: null,
    };
  }
  return null;
});
</script>

<template>
  <router-link
    v-if="origin && origin.to"
    :to="origin.to"
    class="inline-flex items-center gap-1.5 w-fit max-w-full px-2 py-0.5 text-xs rounded-full text-n-blue-11 bg-n-blue-3 hover:underline"
  >
    <span :class="origin.icon" class="shrink-0 size-3.5" />
    <span class="truncate">{{ origin.text }}</span>
  </router-link>
  <span
    v-else-if="origin"
    class="inline-flex items-center gap-1.5 w-fit max-w-full px-2 py-0.5 text-xs rounded-full text-n-slate-11 bg-n-slate-3"
  >
    <span :class="origin.icon" class="shrink-0 size-3.5" />
    <span class="truncate">{{ origin.text }}</span>
  </span>
</template>
