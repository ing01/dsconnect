<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';

import Banner from 'dashboard/components/ui/Banner.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const currentRole = useMapGetter('getCurrentRole');

const assignedAgent = computed(() => currentChat.value?.meta?.assignee);

// Conversa numa fila + quem nao e Administrador: nao existe "Atribuir a mim"
// - so' o botao "Pegar proximo da fila" (a PRIMEIRA da fila).
const isQueueOrderLocked = computed(
  () => !!currentChat.value?.meta?.queue && currentRole.value !== 'administrator'
);

const hasMessage = computed(() => props.message !== '');
const isUserTyping = computed(() => hasMessage.value && !props.isOnPrivateNote);
const isUnassigned = computed(() => !assignedAgent.value);
const isAssignedToOtherAgent = computed(
  () => !!assignedAgent.value && assignedAgent.value?.id !== currentUser.value?.id
);

// Quando a conversa e' de outro atendente, o editor fica bloqueado de
// verdade (ver `ReplyBox#isEditorDisabled`) - sem digitar nada, `isUserTyping`
// nunca ficaria true, e o banner (com o botao "Atribuir a mim" que destrava)
// nunca apareceria. Por isso esse caso mostra o banner sempre, nao so' ao
// digitar; unassigned continua so' avisando depois que a pessoa comeca a
// escrever (nao bloqueia o envio, so' lembra de atribuir).
const showSelfAssignBanner = computed(() => {
  if (props.isOnPrivateNote) return false;
  if (isAssignedToOtherAgent.value) return true;

  return isUserTyping.value && isUnassigned.value;
});

const isPendingConversation = computed(
  () => currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING
);

const isAgentBotOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'AgentBot'
);

const showBotHandoffBanner = computed(() => {
  return isPendingConversation.value && isAgentBotOwned.value;
});

const botAssigneeName = computed(() => {
  if (isAgentBotOwned.value && assignedAgent.value?.name) {
    return assignedAgent.value.name;
  }

  return t('CONVERSATION.BOT_HANDOFF_FALLBACK_ASSIGNEE');
});

const selfAssignConversation = async () => {
  const { avatar_url, ...rest } = currentUser.value || {};
  const conversationId = currentChat.value?.id;
  const previousAgent = assignedAgent.value;
  store.dispatch('setCurrentChatAssignee', {
    conversationId,
    assignee: { ...rest, thumbnail: avatar_url },
    assigneeType: 'User',
  });
  try {
    await store.dispatch('assignAgent', {
      conversationId,
      agentId: rest.id,
    });
  } catch (error) {
    store.dispatch('setCurrentChatAssignee', {
      conversationId,
      assignee: previousAgent || null,
      assigneeType: previousAgent ? 'User' : null,
    });
    throw error;
  }
};

const needsAssignmentToCurrentUser = computed(() => {
  return isUnassigned.value || isAssignedToOtherAgent.value;
});

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation();
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('CONVERSATION.CHANGE_AGENT_FAILED')
    );
  }
};

const reopenConversation = async () => {
  await store.dispatch('toggleStatus', {
    conversationId: currentChat.value?.id,
    status: 'open',
  });
};

const onClickBotHandoff = async () => {
  try {
    const shouldAssignToCurrentUser =
      isAgentBotOwned.value || needsAssignmentToCurrentUser.value;

    await reopenConversation();

    if (shouldAssignToCurrentUser) {
      await selfAssignConversation();
    }

    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('CONVERSATION.BOT_HANDOFF_ERROR')
    );
  }
};
</script>

<template>
  <Banner
    v-if="showSelfAssignBanner && !showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      isQueueOrderLocked
        ? $t('CONVERSATION.QUEUE_ORDER_LOCKED')
        : $t('CONVERSATION.NOT_ASSIGNED_TO_YOU')
    "
    :has-action-button="!isQueueOrderLocked"
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <Banner
    v-if="showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      $t('CONVERSATION.BOT_HANDOFF_MESSAGE', {
        assigneeName: botAssigneeName,
      })
    "
    has-action-button
    :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
    @primary-action="onClickBotHandoff"
  />
</template>
