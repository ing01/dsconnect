<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import TicketsList from './TicketsList.vue';

const store = useStore();
const { t } = useI18n();

const currentChat = computed(() => store.getters.getSelectedChat);
const conversationId = computed(() => currentChat.value.id);

const isOpen = ref(false);
const linkedCount = ref(0);

// The panel reports the count it already loaded, so the badge costs no request
// of its own.
const setCount = count => {
  linkedCount.value = count;
};

// Switching conversations must not leave the previous one's panel hanging open.
watch(conversationId, () => {
  isOpen.value = false;
});
</script>

<template>
  <!-- Anchored to the button rather than opening a modal: seeing the linked
       tickets and adding one are quick actions, not a separate screen. -->
  <OnClickOutside
    class="relative flex items-center"
    @trigger="isOpen = false"
  >
    <Button
      v-tooltip="t('TICKET.CONVERSATION_PANEL.ADD_BUTTON')"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-ticket"
      class="rounded-md"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="isOpen = !isOpen"
    />
    <span
      v-if="linkedCount"
      class="absolute -top-1 -right-1 flex items-center justify-center min-w-[16px] h-4 px-1 rounded-full bg-n-brand text-white text-[10px] font-medium leading-none pointer-events-none"
    >
      {{ linkedCount }}
    </span>

    <TicketsList
      v-if="conversationId"
      :conversation-id="conversationId"
      :is-open="isOpen"
      @close="isOpen = false"
      @count="setCount"
    />
  </OnClickOutside>
</template>
