<script setup>
import { nextTick, ref, watch, computed } from 'vue';
import { useTrack } from 'dashboard/composables';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { useUISettings } from 'dashboard/composables/useUISettings';

import CopilotInput from './CopilotInput.vue';
import CopilotLoader from './CopilotLoader.vue';
import CopilotAgentMessage from './CopilotAgentMessage.vue';
import CopilotAssistantMessage from './CopilotAssistantMessage.vue';
import ToggleCopilotAssistant from './ToggleCopilotAssistant.vue';
import CopilotEmptyState from './CopilotEmptyState.vue';
import CopilotHistory from './CopilotHistory.vue';
import DueBotName from './DueBotName.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: {
    type: Array,
    default: () => [],
  },
  conversationInboxType: {
    type: String,
    required: true,
  },
  assistants: {
    type: Array,
    default: () => [],
  },
  activeAssistant: {
    type: Object,
    default: () => ({}),
  },
  // Historico de conversas do proprio usuario com o DueBot.
  showHistory: {
    type: Boolean,
    default: false,
  },
  threads: {
    type: Array,
    default: () => [],
  },
  isHistoryLoading: {
    type: Boolean,
    default: false,
  },
  hasHistoryError: {
    type: Boolean,
    default: false,
  },
  canLoadMoreHistory: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'sendMessage',
  'reset',
  'setAssistant',
  'toggleHistory',
  'selectThread',
  'loadMoreHistory',
]);

const { t } = useI18n();

const sendMessage = message => {
  emit('sendMessage', message);
  useTrack(COPILOT_EVENTS.SEND_MESSAGE);
};

const chatContainer = ref(null);

const scrollToBottom = async () => {
  await nextTick();
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
  }
};

// As etapas internas da IA (`assistant_thinking`: ferramentas consultadas,
// raciocinio) nao sao mostradas. Enquanto a resposta nao chega, so' o
// CopilotLoader com frases de espera.
const visibleMessages = computed(() =>
  props.messages.filter(
    message => message.message_type !== 'assistant_thinking'
  )
);

const isLastMessageFromAssistant = computed(() => {
  const last = props.messages[props.messages.length - 1];
  return last?.message_type === 'assistant';
});

const { updateUISettings } = useUISettings();

const closeCopilotPanel = () => {
  updateUISettings({
    is_copilot_panel_open: false,
    is_contact_sidebar_open: false,
  });
};

const handleSidebarAction = action => {
  if (action === 'reset') {
    emit('reset');
  }
  if (action === 'history') {
    emit('toggleHistory');
  }
};

const hasAssistants = computed(() => props.assistants.length > 0);
const hasMessages = computed(() => props.messages.length > 0);
const copilotButtons = computed(() => {
  const buttons = [
    {
      key: 'history',
      icon: props.showHistory ? 'i-lucide-message-square' : 'i-lucide-history',
      tooltip: props.showHistory
        ? t('CAPTAIN.COPILOT.HISTORY.BACK')
        : t('CAPTAIN.COPILOT.HISTORY.OPEN'),
    },
  ];
  if (hasMessages.value || props.showHistory) {
    buttons.push({
      key: 'reset',
      icon: 'i-lucide-square-pen',
      tooltip: t('CAPTAIN.COPILOT.NEW_CHAT'),
    });
  }
  return buttons;
});
watch(
  [() => props.messages],
  () => {
    scrollToBottom();
  },
  { deep: true }
);
</script>

<template>
  <div class="flex flex-col h-full text-sm leading-6 tracking-tight w-full">
    <SidebarActionsHeader
      :title="$t('CAPTAIN.COPILOT.TITLE')"
      :buttons="copilotButtons"
      @click="handleSidebarAction"
      @close="closeCopilotPanel"
    >
      <template #title>
        <DueBotName />
      </template>
    </SidebarActionsHeader>
    <div
      ref="chatContainer"
      class="flex-1 flex px-4 py-4 overflow-y-auto items-start"
    >
      <div v-if="showHistory" class="flex-1 flex flex-col w-full">
        <h3 class="mb-3 text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.COPILOT.HISTORY.TITLE') }}
        </h3>
        <CopilotHistory
          :threads="threads"
          :is-loading="isHistoryLoading"
          :has-error="hasHistoryError"
          :can-load-more="canLoadMoreHistory"
          @select="$event => emit('selectThread', $event)"
          @load-more="emit('loadMoreHistory')"
        />
      </div>
      <div
        v-else-if="hasMessages"
        class="space-y-6 flex-1 flex flex-col w-full"
      >
        <template v-for="(item, index) in visibleMessages" :key="item.id">
          <CopilotAgentMessage
            v-if="item.message_type === 'user'"
            :message="item.message"
          />
          <CopilotAssistantMessage
            v-else-if="item.message_type === 'assistant'"
            :message="item.message"
            :is-last-message="index === visibleMessages.length - 1"
            :conversation-inbox-type="conversationInboxType"
          />
        </template>

        <CopilotLoader v-if="!isLastMessageFromAssistant" />
      </div>
      <CopilotEmptyState v-else :has-assistants="hasAssistants" />
    </div>

    <div class="mx-3 mt-px mb-2">
      <div class="flex items-center gap-2 justify-between w-full mb-1">
        <ToggleCopilotAssistant
          v-if="assistants.length > 1"
          :assistants="assistants"
          :active-assistant="activeAssistant"
          @set-assistant="$event => emit('setAssistant', $event)"
        />
        <div v-else />
      </div>
      <CopilotInput
        v-if="hasAssistants && !showHistory"
        class="mb-1 w-full"
        @send="sendMessage"
      />
    </div>
  </div>
</template>
