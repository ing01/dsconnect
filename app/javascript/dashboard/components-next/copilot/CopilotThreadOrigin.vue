<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';

const props = defineProps({
  thread: {
    type: Object,
    required: true,
  },
});

const route = useRoute();

// De onde o chat com o DueBot foi aberto - um link para entrar na conversa ou
// no ticket e ver do que se tratava. Chat aberto fora dos dois nao mostra nada.
const origin = computed(() => {
  const { conversation_display_id: conversationId, ticket } = props.thread;
  const accountId = route?.params?.accountId;

  if (ticket?.id) {
    return {
      key: 'CAPTAIN.COPILOT.HISTORY.ORIGIN_TICKET',
      id: ticket.display_id || ticket.id,
      icon: 'i-lucide-ticket',
      to: frontendURL(`accounts/${accountId}/tickets/${ticket.id}`),
    };
  }
  if (conversationId) {
    return {
      key: 'CAPTAIN.COPILOT.HISTORY.ORIGIN_CONVERSATION',
      id: conversationId,
      icon: 'i-lucide-messages-square',
      to: frontendURL(`accounts/${accountId}/conversations/${conversationId}`),
    };
  }
  return null;
});
</script>

<template>
  <router-link
    v-if="origin"
    :to="origin.to"
    class="inline-flex items-center gap-1.5 w-fit px-2 py-0.5 text-xs rounded-full text-n-blue-11 bg-n-blue-3 hover:underline"
  >
    <span :class="origin.icon" class="size-3.5" />
    {{ $t(origin.key, { id: origin.id }) }}
  </router-link>
</template>
