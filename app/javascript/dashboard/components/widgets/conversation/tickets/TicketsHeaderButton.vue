<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import TicketsList from './TicketsList.vue';
import TicketsAPI from 'dashboard/api/tickets';

const store = useStore();
const { t } = useI18n();

const currentChat = computed(() => store.getters.getSelectedChat);
const conversationId = computed(() => currentChat.value.id);

const showModal = ref(false);
const linkedCount = ref(0);

const loadCount = async () => {
  if (!conversationId.value) return;
  try {
    const response = await TicketsAPI.getByConversation(conversationId.value);
    linkedCount.value = response.data?.payload?.length || 0;
  } catch (error) {
    linkedCount.value = 0;
  }
};

const openModal = () => {
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
  loadCount();
};

watch(conversationId, loadCount);
onMounted(loadCount);
</script>

<template>
  <div class="relative flex items-center">
    <Button
      v-tooltip="t('TICKET.CONVERSATION_PANEL.ADD_BUTTON')"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-ticket"
      class="rounded-md"
      @click="openModal"
    />
    <span
      v-if="linkedCount"
      class="absolute -top-1 -right-1 flex items-center justify-center min-w-[16px] h-4 px-1 rounded-full bg-n-brand text-white text-[10px] font-medium leading-none"
    >
      {{ linkedCount }}
    </span>

    <woot-modal v-model:show="showModal" :on-close="closeModal">
      <div class="p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-2 px-2 pt-2">
          {{ t('CONVERSATION_SIDEBAR.ACCORDION.TICKETS') }}
        </h3>
        <TicketsList :conversation-id="conversationId" />
      </div>
    </woot-modal>
  </div>
</template>
