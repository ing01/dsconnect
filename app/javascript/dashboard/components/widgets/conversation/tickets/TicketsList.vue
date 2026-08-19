<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import TicketsAPI from 'dashboard/api/tickets';
import CreateOrLinkTicket from './CreateOrLinkTicket.vue';
import TicketListItem from './TicketListItem.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const tickets = ref([]);
const isLoading = ref(false);
const shouldShowCreateModal = ref(false);

const hasTickets = computed(() => tickets.value.length > 0);
const linkedTicketIds = computed(() => tickets.value.map(ticket => ticket.id));

const loadTickets = async () => {
  isLoading.value = true;
  try {
    const response = await TicketsAPI.getByConversation(props.conversationId);
    tickets.value = response.data || [];
  } catch (error) {
    // Silent fail - not critical for UX
  } finally {
    isLoading.value = false;
  }
};

const unlinkTicket = async ticketId => {
  try {
    await TicketsAPI.unlinkConversation(ticketId, props.conversationId);
    tickets.value = tickets.value.filter(ticket => ticket.id !== ticketId);
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  }
};

const openCreateModal = () => {
  shouldShowCreateModal.value = true;
};

const closeCreateModal = () => {
  shouldShowCreateModal.value = false;
  loadTickets();
};

watch(
  () => props.conversationId,
  () => loadTickets()
);

onMounted(loadTickets);
</script>

<template>
  <div>
    <div class="px-4 pt-3 pb-2">
      <NextButton
        ghost
        xs
        icon="i-lucide-plus"
        :label="t('TICKET.CONVERSATION_PANEL.ADD_BUTTON')"
        @click="openCreateModal"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center p-8">
      <Spinner />
    </div>

    <div v-else-if="!hasTickets" class="flex justify-center p-4">
      <p class="text-sm text-n-slate-11">
        {{ t('TICKET.CONVERSATION_PANEL.NO_LINKED_TICKETS') }}
      </p>
    </div>

    <div v-else class="max-h-[300px] overflow-y-auto">
      <TicketListItem
        v-for="ticket in tickets"
        :key="ticket.id"
        class="px-4 pt-3 pb-4 border-b border-n-weak last:border-b-0"
        :ticket="ticket"
        @unlink="unlinkTicket"
      />
    </div>

    <woot-modal
      v-model:show="shouldShowCreateModal"
      :on-close="closeCreateModal"
      :close-on-backdrop-click="false"
    >
      <CreateOrLinkTicket
        :conversation-id="conversationId"
        :linked-ticket-ids="linkedTicketIds"
        @close="closeCreateModal"
        @linked="closeCreateModal"
      />
    </woot-modal>
  </div>
</template>
