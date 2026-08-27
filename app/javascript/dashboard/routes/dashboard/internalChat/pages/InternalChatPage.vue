<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';

import ChatSidebar from '../components/ChatSidebar.vue';
import ChatHeader from '../components/ChatHeader.vue';
import ChatMessage from '../components/ChatMessage.vue';
import ChatComposer from '../components/ChatComposer.vue';
import NewConversationDialog from '../components/NewConversationDialog.vue';
import CreateChannelDialog from '../components/CreateChannelDialog.vue';
import ImageLightbox from '../components/ImageLightbox.vue';
import { continuesBlock } from '../helpers/messageParser';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const router = useRouter();
const route = useRoute();

const users = computed(() => getters['internalChat/getUsers'].value);
const directs = computed(() => getters['internalChat/getDirects'].value);
const channels = computed(() => getters['internalChat/getChannels'].value);
const currentUserId = computed(
  () => getters['internalChat/getCurrentUserId'].value
);

const activeRoomId = ref('');
// No celular a lista e a conversa não dividem a tela: uma substitui a outra.
const showConversationOnMobile = ref(false);
const messageQuery = ref('');
const replyTo = ref(null);
const lightboxAttachment = ref(null);
const scrollerRef = ref(null);

const newConversationDialog = ref(null);
const createChannelDialog = ref(null);

const activeRoom = computed(() =>
  activeRoomId.value
    ? getters['internalChat/getRoomById'].value(activeRoomId.value)
    : null
);

const isChannel = computed(() => !!activeRoom.value?.name);

const peer = computed(() =>
  isChannel.value || !activeRoom.value
    ? null
    : users.value.find(user => user.id === activeRoom.value.userId)
);

const userFor = id => users.value.find(user => user.id === id);

// Quantas mensagens do fim ainda não foram lidas, para desenhar a régua.
const unreadFrom = ref(0);

const visibleMessages = computed(() => {
  const messages = activeRoom.value?.messages || [];
  if (!messageQuery.value.trim()) return messages;

  const term = messageQuery.value.toLowerCase();
  return messages.filter(message => message.body?.toLowerCase().includes(term));
});

const messageAt = id => activeRoom.value?.messages.find(item => item.id === id);

const scrollToBottom = () => {
  nextTick(() => {
    const element = scrollerRef.value;
    if (element) element.scrollTop = element.scrollHeight;
  });
};

const openRoom = roomId => {
  const room = getters['internalChat/getRoomById'].value(roomId);
  unreadFrom.value = room?.unread || 0;

  activeRoomId.value = roomId;
  showConversationOnMobile.value = true;
  messageQuery.value = '';
  replyTo.value = null;

  store.dispatch('internalChat/markRead', roomId);
  scrollToBottom();
};

// Os agentes da conta são o diretório do Chat - é com eles que se conversa.
// Sem esta busca a tela nasceria vazia numa sessão que ainda não os carregou.
onMounted(async () => {
  await store.dispatch('agents/get');
  await store.dispatch('internalChat/initialise');

  const initial =
    route.query.room || directs.value[0]?.id || channels.value[0]?.id;
  if (initial) openRoom(initial);
});

watch(activeRoomId, () => scrollToBottom());

const send = payload => {
  store.dispatch('internalChat/sendMessage', {
    roomId: activeRoomId.value,
    ...payload,
  });
  replyTo.value = null;
  unreadFrom.value = 0;
  scrollToBottom();
};

const react = ({ messageId, emoji }) =>
  store.dispatch('internalChat/toggleReaction', {
    roomId: activeRoomId.value,
    messageId,
    emoji,
  });

const startConversation = async userId => {
  const direct = await store.dispatch('internalChat/openDirect', userId);
  openRoom(direct.id);
};

const createChannel = async payload => {
  const channel = await store.dispatch('internalChat/createChannel', payload);
  openRoom(channel.id);
};

// A referência de Ticket leva ao Ticket de verdade - é a integração que
// justifica o Chat morar dentro da plataforma em vez de fora dela.
const openTicket = ticketId =>
  router.push(
    frontendURL(`accounts/${route.params.accountId}/tickets/${ticketId}`)
  );

const isGrouped = index =>
  continuesBlock(
    visibleMessages.value[index],
    visibleMessages.value[index - 1]
  );

// A régua de não lidas fica antes da primeira mensagem ainda não vista.
const unreadDividerIndex = computed(() => {
  if (!unreadFrom.value) return -1;

  const index = visibleMessages.value.length - unreadFrom.value;
  return index > 0 ? index : -1;
});
</script>

<template>
  <div class="flex w-full h-full min-h-0 bg-n-solid-2">
    <!-- Barra lateral própria do módulo: no celular ela é a tela inteira até
         alguém escolher uma conversa. -->
    <div
      class="w-full md:w-72 lg:w-80 md:shrink-0 h-full min-h-0"
      :class="showConversationOnMobile ? 'hidden md:block' : 'block'"
    >
      <ChatSidebar
        :directs="directs"
        :channels="channels"
        :users="users"
        :active-room-id="activeRoomId"
        @select="openRoom"
        @new-conversation="newConversationDialog?.open()"
        @create-channel="createChannelDialog?.open()"
      />
    </div>

    <section
      class="flex-col w-full h-full min-w-0 min-h-0 grow bg-n-solid-1"
      :class="showConversationOnMobile ? 'flex' : 'hidden md:flex'"
    >
      <template v-if="activeRoom">
        <ChatHeader
          :room="activeRoom"
          :peer="peer"
          @back="showConversationOnMobile = false"
          @search="value => (messageQuery = value)"
        />

        <div ref="scrollerRef" class="flex flex-col py-2 overflow-y-auto grow">
          <template
            v-for="(message, index) in visibleMessages"
            :key="message.id"
          >
            <div
              v-if="index === unreadDividerIndex"
              class="flex items-center gap-3 px-4 py-2"
            >
              <span class="h-px grow bg-n-ruby-8" />
              <span class="text-xs font-medium text-n-ruby-11">
                {{ t('INTERNAL_CHAT.UNREAD_DIVIDER', { count: unreadFrom }) }}
              </span>
              <span class="h-px grow bg-n-ruby-8" />
            </div>

            <ChatMessage
              :message="message"
              :author="userFor(message.userId)"
              :users="users"
              :current-user-id="currentUserId"
              :grouped="isGrouped(index)"
              :replied-message="
                message.replyTo ? messageAt(message.replyTo) : null
              "
              :replied-author="
                message.replyTo
                  ? userFor(messageAt(message.replyTo)?.userId)
                  : null
              "
              @reply="value => (replyTo = value)"
              @react="react"
              @open-image="attachment => (lightboxAttachment = attachment)"
              @open-ticket="openTicket"
            />
          </template>

          <p
            v-if="!visibleMessages.length"
            class="px-4 py-8 text-sm text-center text-n-slate-10"
          >
            {{
              messageQuery
                ? t('INTERNAL_CHAT.SEARCH_EMPTY')
                : t('INTERNAL_CHAT.ROOM_EMPTY')
            }}
          </p>
        </div>

        <ChatComposer
          :users="users"
          :reply-to="replyTo"
          :reply-author="replyTo ? userFor(replyTo.userId) : null"
          :placeholder="
            isChannel
              ? t('INTERNAL_CHAT.COMPOSER.PLACEHOLDER_CHANNEL', {
                  name: activeRoom.name,
                })
              : t('INTERNAL_CHAT.COMPOSER.PLACEHOLDER_DIRECT', {
                  name: peer?.name,
                })
          "
          @send="send"
          @cancel-reply="replyTo = null"
        />
      </template>

      <p v-else class="p-8 text-sm text-center text-n-slate-10">
        {{ t('INTERNAL_CHAT.NO_ROOM') }}
      </p>
    </section>

    <NewConversationDialog
      ref="newConversationDialog"
      :users="users"
      :current-user-id="currentUserId"
      @select="startConversation"
    />

    <CreateChannelDialog
      ref="createChannelDialog"
      :users="users"
      :current-user-id="currentUserId"
      @create="createChannel"
    />

    <ImageLightbox
      :attachment="lightboxAttachment"
      @close="lightboxAttachment = null"
    />
  </div>
</template>
