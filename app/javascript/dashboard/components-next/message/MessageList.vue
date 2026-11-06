<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Message from './Message.vue';
import { MESSAGE_TYPES } from './constants.js';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useMapGetter } from 'dashboard/composables/store.js';
import MessageApi from 'dashboard/api/inbox/message.js';
import {
  startsConversationBlock,
  formatHistoryDate,
} from './helpers/contactHistoryHelper.js';

/**
 * Props definition for the component
 * @typedef {Object} Props
 * @property {Array} readMessages - Array of read messages
 * @property {Array} unReadMessages - Array of unread messages
 * @property {Number} currentUserId - ID of the current user
 * @property {Boolean} isAnEmailChannel - Whether this is an email channel
 * @property {Object} inboxSupportsReplyTo - Inbox reply support configuration
 * @property {Array} messages - Array of all messages [These are not in camelcase]
 * @property {Array} historyMessages - Messages of the contact's PREVIOUS conversations (oldest first) [not in camelcase]
 * @property {Object} historyConversations - Previous conversations data, indexed by display_id
 * @property {Number} currentConversationId - display_id of the open conversation
 */
const props = defineProps({
  currentUserId: {
    type: Number,
    required: true,
  },
  firstUnreadId: {
    type: Number,
    default: null,
  },
  isAnEmailChannel: {
    type: Boolean,
    default: false,
  },
  inboxSupportsReplyTo: {
    type: Object,
    default: () => ({ incoming: false, outgoing: false }),
  },
  messages: {
    type: Array,
    default: () => [],
  },
  // Historico do cliente: mensagens das conversas anteriores, mostradas acima das
  // da conversa atual, so leitura.
  historyMessages: {
    type: Array,
    default: () => [],
  },
  historyConversations: {
    type: Object,
    default: () => ({}),
  },
  currentConversationId: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['retry']);

const { t, locale } = useI18n();

const CAMEL_CASE_OPTIONS = {
  deep: true,
  stopPaths: [
    'content_attributes.translations',
    'content_attributes.whatsapp_flow_response.response_json',
  ],
};

const allMessages = computed(() => {
  return useCamelCase(props.messages, CAMEL_CASE_OPTIONS);
});

const historyList = computed(() => {
  return useCamelCase(props.historyMessages, CAMEL_CASE_OPTIONS);
});

// Titulo da divisoria de cada conversa anterior: "Conversa anterior #12 · WhatsApp · 04/11/2026 10:30".
const historyBlockLabel = conversationId => {
  const conversation = props.historyConversations[conversationId] || {};
  return [
    t('CONVERSATION.CONTACT_HISTORY.PREVIOUS', { id: conversationId }),
    conversation.inbox_name,
    formatHistoryDate(conversation.created_at, locale.value),
  ]
    .filter(Boolean)
    .join(' · ');
};

const isEmailHistoryMessage = message =>
  props.historyConversations[message.conversationId]?.channel_type ===
  'Channel::Email';

// Resposta dentro do proprio historico: so procura nas mensagens carregadas dele,
// nunca busca na conversa atual (o id seria de outra conversa).
const getHistoryInReplyTo = message => {
  const inReplyToId = message.contentAttributes?.inReplyTo;
  if (!inReplyToId) return null;

  return historyList.value.find(item => item.id === inReplyToId) || null;
};

const currentChat = useMapGetter('getSelectedChat');

// Cache for fetched reply messages to avoid duplicate API calls
const fetchedReplyMessages = reactive(new Map());

/**
 * Fetches a specific message from the API by trying to get messages around it
 * @param {number} messageId - The ID of the message to fetch
 * @param {number} conversationId - The ID of the conversation
 * @returns {Promise<Object|null>} - The fetched message or null if not found/error
 */
const fetchReplyMessage = async (messageId, conversationId) => {
  // Return cached result if already fetched
  if (fetchedReplyMessages.has(messageId)) {
    return fetchedReplyMessages.get(messageId);
  }

  try {
    const response = await MessageApi.getPreviousMessages({
      conversationId,
      before: messageId + 100,
      after: messageId - 100,
    });

    const messages = response.data?.payload || [];
    const targetMessage = messages.find(msg => msg.id === messageId);

    if (targetMessage) {
      const camelCaseMessage = useCamelCase(targetMessage);
      fetchedReplyMessages.set(messageId, camelCaseMessage);
      return camelCaseMessage;
    }

    // Cache null result to avoid repeated API calls
    fetchedReplyMessages.set(messageId, null);
    return null;
  } catch (error) {
    fetchedReplyMessages.set(messageId, null);
    return null;
  }
};

/**
 * Determines if a message should be grouped with the next message
 * @param {Number} index - Index of the current message
 * @param {Array} searchList - Array of messages to check
 * @returns {Boolean} - Whether the message should be grouped with next
 */
const shouldGroupWithNext = (index, searchList) => {
  if (index === searchList.length - 1) return false;

  const current = searchList[index];
  const next = searchList[index + 1];

  if (next.status === 'failed') return false;

  const nextSenderId = next.senderId ?? next.sender?.id;
  const currentSenderId = current.senderId ?? current.sender?.id;
  const hasSameSender = nextSenderId === currentSenderId;

  const nextMessageType = next.messageType;
  const currentMessageType = current.messageType;

  const areBothTemplates =
    nextMessageType === MESSAGE_TYPES.TEMPLATE &&
    currentMessageType === MESSAGE_TYPES.TEMPLATE;

  if (!hasSameSender || areBothTemplates) return false;

  if (currentMessageType !== nextMessageType) return false;

  // Check if messages are in the same minute by rounding down to nearest minute
  return Math.floor(next.createdAt / 60) === Math.floor(current.createdAt / 60);
};

/**
 * Gets the message that was replied to
 * @param {Object} parentMessage - The message containing the reply reference
 * @returns {Object|null} - The message being replied to, or null if not found
 */
const getInReplyToMessage = parentMessage => {
  if (!parentMessage) return null;

  const inReplyToMessageId =
    parentMessage.contentAttributes?.inReplyTo ??
    parentMessage.content_attributes?.in_reply_to;

  if (!inReplyToMessageId) return null;

  // Try to find in current messages first
  let replyMessage = props.messages?.find(msg => msg.id === inReplyToMessageId);

  // Then try store messages
  if (!replyMessage && currentChat.value?.messages) {
    replyMessage = currentChat.value.messages.find(
      msg => msg.id === inReplyToMessageId
    );
  }

  // Then check fetch cache
  if (!replyMessage && fetchedReplyMessages.has(inReplyToMessageId)) {
    replyMessage = fetchedReplyMessages.get(inReplyToMessageId);
  }

  // If still not found and we have conversation context, fetch it
  if (!replyMessage && currentChat.value?.id) {
    fetchReplyMessage(inReplyToMessageId, currentChat.value.id);
    return null; // Let UI handle loading state
  }

  return replyMessage ? useCamelCase(replyMessage) : null;
};
</script>

<template>
  <ul class="px-4 bg-n-surface-1">
    <slot name="beforeAll" />
    <template
      v-for="(message, index) in historyList"
      :key="`history-${message.id}`"
    >
      <li
        v-if="startsConversationBlock(historyList, index)"
        class="flex justify-center my-3 list-none"
        role="separator"
      >
        <span
          class="px-3 py-1 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
        >
          {{ historyBlockLabel(message.conversationId) }}
        </span>
      </li>
      <Message
        v-bind="message"
        readonly
        :is-email-inbox="isEmailHistoryMessage(message)"
        :in-reply-to="getHistoryInReplyTo(message)"
        :group-with-next="shouldGroupWithNext(index, historyList)"
        :current-user-id="currentUserId"
        data-clarity-mask="True"
      />
    </template>
    <li
      v-if="historyList.length && currentConversationId"
      class="flex justify-center my-3 list-none"
      role="separator"
    >
      <span
        class="px-3 py-1 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
      >
        {{
          t('CONVERSATION.CONTACT_HISTORY.CURRENT', {
            id: currentConversationId,
          })
        }}
      </span>
    </li>
    <slot name="beforeMessages" />
    <template v-for="(message, index) in allMessages" :key="message.id">
      <slot
        v-if="firstUnreadId && message.id === firstUnreadId"
        name="unreadBadge"
      />
      <Message
        v-bind="message"
        :is-email-inbox="isAnEmailChannel"
        :in-reply-to="getInReplyToMessage(message)"
        :group-with-next="shouldGroupWithNext(index, allMessages)"
        :inbox-supports-reply-to="inboxSupportsReplyTo"
        :current-user-id="currentUserId"
        data-clarity-mask="True"
        @retry="emit('retry', message)"
      />
    </template>
    <slot name="after" />
  </ul>
</template>
