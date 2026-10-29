<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Copilot from 'dashboard/components-next/copilot/Copilot.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConfig } from 'dashboard/composables/useConfig';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import wootConstants from 'dashboard/constants/globals';
import CopilotThreadsAPI from 'dashboard/api/captain/copilotThreads';
import CopilotMessagesAPI from 'dashboard/api/captain/copilotMessages';

defineProps({
  conversationInboxType: {
    type: String,
    default: '',
  },
});

const store = useStore();
const route = useRoute();
const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();
const { isEnterprise } = useConfig();
const { width: windowWidth } = useWindowSize();

const currentUser = useMapGetter('getCurrentUser');
const assistants = useMapGetter('captainAssistants/getRecords');
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const inboxAssistant = useMapGetter('getCopilotAssistant');
const currentChat = useMapGetter('getSelectedChat');

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const selectedCopilotThreadId = ref(null);
// A conversa do DueBot aberta agora (para mostrar de onde ela foi aberta).
const selectedThread = ref(null);

// De onde a pessoa esta falando com o DueBot: numa Conversa ou num Ticket. Vem
// da rota (e nao do `getSelectedChat`, que fica guardado ao sair da conversa).
const currentTicketId = computed(() =>
  route?.name === 'ticket_detail' ? route.params.ticketId : null
);
const currentConversationId = computed(() =>
  String(route?.name || '').includes('conversation')
    ? currentChat.value?.id
    : null
);
const messages = computed(() =>
  store.getters['copilotMessages/getMessagesByThreadId'](
    selectedCopilotThreadId.value
  )
);

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const selectedAssistantId = ref(null);

const activeAssistant = computed(() => {
  const preferredId = uiSettings.value.preferred_captain_assistant_id;

  // If the user has selected a specific assistant, it takes first preference for Copilot.
  if (preferredId) {
    const preferredAssistant = assistants.value.find(a => a.id === preferredId);
    // Return the preferred assistant if found, otherwise continue to next cases
    if (preferredAssistant) return preferredAssistant;
  }

  // If the above is not available, the assistant connected to the inbox takes preference.
  if (inboxAssistant.value) {
    const inboxMatchedAssistant = assistants.value.find(
      a => a.id === inboxAssistant.value.id
    );
    if (inboxMatchedAssistant) return inboxMatchedAssistant;
  }
  // If neither of the above is available, the first assistant in the account takes preference.
  return assistants.value[0];
});

const closeCopilotPanel = () => {
  if (isSmallScreen.value && uiSettings.value?.is_copilot_panel_open) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    });
  }
};

const setAssistant = async assistant => {
  selectedAssistantId.value = assistant.id;
  await updateUISettings({
    preferred_captain_assistant_id: assistant.id,
  });
};

const shouldShowCopilotPanel = computed(() => {
  if (!isEnterprise) {
    return false;
  }
  const isCaptainEnabled = isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CAPTAIN
  );
  const { is_copilot_panel_open: isCopilotPanelOpen } = uiSettings.value;
  return isCaptainEnabled && isCopilotPanelOpen && !uiFlags.value.fetchingList;
});

// Historico: as conversas do proprio usuario com o DueBot ficam salvas no
// servidor (CopilotThread); aqui so' listamos e reabrimos uma delas.
const HISTORY_PAGE_SIZE = 20;
const showHistory = ref(false);
const historyThreads = ref([]);
const historyPage = ref(1);
const canLoadMoreHistory = ref(false);
const isHistoryLoading = ref(false);
const hasHistoryError = ref(false);

const loadHistory = async (page = 1) => {
  isHistoryLoading.value = true;
  hasHistoryError.value = false;
  try {
    const { data } = await CopilotThreadsAPI.get({ page });
    const threads = data.payload || [];
    historyThreads.value =
      page === 1 ? threads : [...historyThreads.value, ...threads];
    historyPage.value = page;
    canLoadMoreHistory.value = threads.length >= HISTORY_PAGE_SIZE;
  } catch (error) {
    hasHistoryError.value = true;
  } finally {
    isHistoryLoading.value = false;
  }
};

const toggleHistory = () => {
  showHistory.value = !showHistory.value;
  if (showHistory.value) loadHistory(1);
};

const loadMoreHistory = () => loadHistory(historyPage.value + 1);

const openThread = async thread => {
  try {
    const { data } = await CopilotMessagesAPI.get(thread.id);
    await Promise.all(
      (data.payload || []).map(message =>
        store.dispatch('copilotMessages/upsert', message)
      )
    );
    selectedCopilotThreadId.value = thread.id;
    selectedThread.value = thread;
    showHistory.value = false;
  } catch (error) {
    useAlert(error.message);
  }
};

const deleteThread = async thread => {
  try {
    await CopilotThreadsAPI.delete(thread.id);
    historyThreads.value = historyThreads.value.filter(
      item => item.id !== thread.id
    );
    // Excluiu a que estava aberta: volta para uma conversa em branco.
    if (selectedCopilotThreadId.value === thread.id) {
      selectedCopilotThreadId.value = null;
      selectedThread.value = null;
    }
  } catch (error) {
    useAlert(t('CAPTAIN.COPILOT.HISTORY.DELETE_ERROR'));
  }
};

const handleReset = () => {
  selectedCopilotThreadId.value = null;
  selectedThread.value = null;
  showHistory.value = false;
};

watch(() => currentChat.value?.id, handleReset);

const sendMessage = async payload => {
  const message = typeof payload === 'string' ? payload : payload.message;
  const requestType =
    typeof payload === 'string' ? undefined : payload.requestType;

  try {
    if (selectedCopilotThreadId.value) {
      await store.dispatch('copilotMessages/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: currentConversationId.value,
        threadId: selectedCopilotThreadId.value,
        message,
      });
    } else {
      const conversationId = currentConversationId.value;
      const response = await store.dispatch('copilotThreads/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: conversationId,
        ...(currentTicketId.value && { ticket_id: currentTicketId.value }),
        message,
        ...(requestType && { request_type: requestType }),
      });
      if (currentConversationId.value === conversationId) {
        selectedCopilotThreadId.value = response.id;
        selectedThread.value = response;
      }
    }
  } catch (error) {
    useAlert(error.message);
  }
};

onMounted(() => {
  if (isEnterprise) {
    store.dispatch('captainAssistants/get');
  }
});
</script>

<template>
  <div
    v-if="shouldShowCopilotPanel"
    v-on-click-outside="() => closeCopilotPanel()"
    class="bg-n-surface-2 h-full overflow-hidden flex-col fixed top-0 ltr:right-0 rtl:left-0 z-40 w-full max-w-sm transition-transform duration-300 ease-in-out md:static md:w-[320px] md:min-w-[320px] ltr:border-l rtl:border-r border-n-weak 2xl:min-w-[360px] 2xl:w-[360px] shadow-lg md:shadow-none"
    :class="[
      {
        'md:flex': shouldShowCopilotPanel,
        'md:hidden': !shouldShowCopilotPanel,
      },
    ]"
  >
    <Copilot
      :messages="messages"
      :support-agent="currentUser"
      :conversation-inbox-type="conversationInboxType"
      :assistants="assistants"
      :active-assistant="activeAssistant"
      :thread="selectedThread"
      :show-history="showHistory"
      :threads="historyThreads"
      :is-history-loading="isHistoryLoading"
      :has-history-error="hasHistoryError"
      :can-load-more-history="canLoadMoreHistory"
      @set-assistant="setAssistant"
      @send-message="sendMessage"
      @reset="handleReset"
      @toggle-history="toggleHistory"
      @select-thread="openThread"
      @load-more-history="loadMoreHistory"
      @delete-thread="deleteThread"
    />
  </div>
  <template v-else />
</template>
