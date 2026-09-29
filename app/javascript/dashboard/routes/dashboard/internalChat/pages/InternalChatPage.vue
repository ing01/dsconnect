<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import ChatSidebar from '../components/ChatSidebar.vue';
import ChatHeader from '../components/ChatHeader.vue';
import ChatMessage from '../components/ChatMessage.vue';
import ChatComposer from '../components/ChatComposer.vue';
import NewConversationDialog from '../components/NewConversationDialog.vue';
import CreateChannelDialog from '../components/CreateChannelDialog.vue';
import ManageMembersDialog from '../components/ManageMembersDialog.vue';
import EditChannelDialog from '../components/EditChannelDialog.vue';
import ChannelMembersPanel from '../components/ChannelMembersPanel.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
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
// Administrador apaga qualquer mensagem, porque responde pelo que fica no Chat da
// empresa. A regra de verdade esta no servidor; isto so decide o que a tela
// oferece.
const isAdministrator = computed(
  () => getters.getCurrentRole?.value === 'administrator'
);

// Sempre NUMERO, nunca texto. O id da sala vem de tres lugares - a barra
// lateral, a criacao de canal/conversa e a query `?room=` da notificacao - e o
// ultimo chega como texto. `getRoomById` compara com `===`, entao "7" nao
// encontrava a sala 7: o clique na notificacao abria o Chat sem abrir a conversa.
const activeRoomId = ref(null);
// No celular a lista e a conversa não dividem a tela: uma substitui a outra.
const showConversationOnMobile = ref(false);
const messageQuery = ref('');
const replyTo = ref(null);
const lightboxAttachment = ref(null);
const scrollerRef = ref(null);

const newConversationDialog = ref(null);
const editChannelDialog = ref(null);
const deleteDialog = ref(null);
const deleteChannelDialog = ref(null);
// A mensagem que espera confirmacao. Guardada aqui, e nao no dialogo, porque e
// quem apaga - o dialogo so pergunta.
const pendingDelete = ref(null);
// O painel de membros e por sala: abrir um canal e voltar nao deve trazer de
// volta o painel que a pessoa fechou noutro.
const membersOpen = ref(false);
const createChannelDialog = ref(null);
const manageMembersDialog = ref(null);
const showPinnedMessages = ref(false);

const activeRoom = computed(() =>
  activeRoomId.value
    ? getters['internalChat/getRoomById'].value(activeRoomId.value)
    : null
);

// O tipo vem do servidor: canal e conversa privada são o mesmo registro com
// `kind` diferente.
const isChannel = computed(() => activeRoom.value?.kind === 'channel');

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

const pinnedMessages = computed(() =>
  activeRoomId.value
    ? getters['internalChat/getPinnedMessages'].value(activeRoomId.value)
    : []
);

const scrollToBottom = () => {
  nextTick(() => {
    const element = scrollerRef.value;
    if (element) element.scrollTop = element.scrollHeight;
  });
};

const openRoom = async entrada => {
  const roomId = Number(entrada);
  if (!Number.isFinite(roomId)) return;

  const room = getters['internalChat/getRoomById'].value(roomId);
  unreadFrom.value = room?.unread || 0;

  activeRoomId.value = roomId;
  // O store precisa saber qual sala está aberta para não contar como não lida
  // uma mensagem que chega enquanto ela está à vista.
  store.dispatch('internalChat/setActiveRoom', roomId);
  showConversationOnMobile.value = true;
  messageQuery.value = '';
  replyTo.value = null;

  // O histórico vem do servidor ao abrir a sala, e não junto da lista: assim a
  // primeira tela não carrega toda a conversa de todo mundo.
  await store.dispatch('internalChat/fetchMessages', roomId);
  store.dispatch('internalChat/markRead', roomId);
  store.dispatch('internalChat/fetchPinnedMessages', roomId);
  showPinnedMessages.value = false;
  scrollToBottom();
};

// Os agentes da conta são o diretório do Chat - é com eles que se conversa.
onMounted(async () => {
  await store.dispatch('agents/get');
  store.dispatch('internalChat/setDirectory');
  await store.dispatch('internalChat/fetchRooms');

  const initial =
    route.query.room || directs.value[0]?.id || channels.value[0]?.id;
  if (initial) await openRoom(initial);
});

// A notificacao pode chegar com a tela do Chat JA aberta. Nesse caso o router
// so troca a query, o componente nao remonta e o `onMounted` acima nao roda de
// novo - sem este observador, clicar no aviso nao levava a lugar nenhum.
watch(
  () => route.query.room,
  room => {
    if (!room) return;
    if (Number(room) === activeRoomId.value) return;

    openRoom(room);
  }
);

watch(activeRoomId, () => {
  scrollToBottom();
  // O painel e de um canal: manter aberto ao trocar de sala mostraria os membros
  // de uma sala olhando para outra.
  membersOpen.value = false;
});

// Sair da tela não deixa uma sala marcada como aberta: dali em diante toda
// mensagem que chegar deve contar como não lida.
onBeforeUnmount(() => store.dispatch('internalChat/setActiveRoom', null));

const send = async payload => {
  await store.dispatch('internalChat/sendMessage', {
    roomId: activeRoomId.value,
    ...payload,
  });
  replyTo.value = null;
  unreadFrom.value = 0;
  scrollToBottom();
};

// Apagar nao tem volta, entao a tela pergunta antes - num dialogo do proprio
// sistema, e nao no `confirm` do navegador, que ignora o tema e aparece colado no
// topo da janela como um aviso de erro. A recusa do servidor continua valendo por
// cima disto.
const askDelete = message => {
  pendingDelete.value = message;
  deleteDialog.value?.open();
};

const confirmDelete = async () => {
  const message = pendingDelete.value;
  pendingDelete.value = null;
  // O `Dialog` emite `confirm` e nao se fecha sozinho - quem o usa fecha. E
  // fecha ANTES de esperar a rede: quem confirmou ja decidiu, e o modal parado
  // esperando a resposta passa a impressao de que o clique nao funcionou. Se a
  // exclusao falhar, o aviso explica e a mensagem continua na lista.
  deleteDialog.value?.close();
  if (!message) return;

  try {
    await store.dispatch('internalChat/deleteMessage', {
      roomId: activeRoomId.value,
      messageId: message.id,
    });
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('INTERNAL_CHAT.MESSAGE.DELETE_ERROR')
    );
  }
};

const saveChannel = async payload => {
  try {
    await store.dispatch('internalChat/updateChannel', payload);
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('INTERNAL_CHAT.EDIT_CHANNEL.ERROR')
    );
  }
};

const react = ({ messageId, emoji }) =>
  store.dispatch('internalChat/toggleReaction', {
    roomId: activeRoomId.value,
    messageId,
    emoji,
  });

const togglePin = messageId =>
  store.dispatch('internalChat/togglePin', {
    roomId: activeRoomId.value,
    messageId,
  });

const askDeleteChannel = () => {
  if (!activeRoom.value) return;

  deleteChannelDialog.value?.open();
};

const deleteChannel = async () => {
  const room = activeRoom.value;
  // Fecha antes de esperar a rede, como o dialogo da mensagem.
  deleteChannelDialog.value?.close();
  if (!room) return;

  try {
    await store.dispatch('internalChat/deleteChannel', room.id);
    activeRoomId.value = '';
    const next = directs.value[0]?.id || channels.value[0]?.id;
    if (next) await openRoom(next);
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.HEADER.DELETE_CHANNEL_ERROR'));
  }
};

const openManageMembers = () =>
  manageMembersDialog.value?.open(activeRoom.value);

const addMember = async userId => {
  try {
    await store.dispatch('internalChat/addMember', {
      roomId: activeRoomId.value,
      userId,
    });
    manageMembersDialog.value?.open(activeRoom.value);
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.MEMBERS.ERROR'));
  }
};

const removeMember = async userId => {
  try {
    await store.dispatch('internalChat/removeMember', {
      roomId: activeRoomId.value,
      userId,
    });
    manageMembersDialog.value?.open(activeRoom.value);
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.MEMBERS.ERROR'));
  }
};

const startConversation = async userId => {
  const direct = await store.dispatch('internalChat/openDirect', userId);
  await openRoom(direct.id);
};

const createChannel = async payload => {
  const channel = await store.dispatch('internalChat/createChannel', payload);
  await openRoom(channel.id);
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
        :can-edit="isAdministrator"
        @select="openRoom"
        @new-conversation="newConversationDialog?.open()"
        @create-channel="createChannelDialog?.open()"
        @edit-channel="channel => editChannelDialog?.open(channel)"
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
          :pinned-count="pinnedMessages.length"
          :can-edit="isAdministrator"
          :members-open="membersOpen"
          @back="showConversationOnMobile = false"
          @search="value => (messageQuery = value)"
          @toggle-members="membersOpen = !membersOpen"
          @edit="editChannelDialog?.open(activeRoom)"
          @manage-members="openManageMembers"
          @delete-channel="askDeleteChannel"
          @toggle-pinned="showPinnedMessages = !showPinnedMessages"
        />

        <div
          v-if="showPinnedMessages"
          class="flex flex-col gap-1 px-4 py-2 border-b max-h-40 overflow-y-auto border-n-weak bg-n-amber-2"
        >
          <p v-if="!pinnedMessages.length" class="text-xs text-n-slate-10 mb-0">
            {{ t('INTERNAL_CHAT.MESSAGE.NO_PINNED') }}
          </p>
          <div
            v-for="pinned in pinnedMessages"
            :key="pinned.id"
            class="flex items-baseline gap-2 text-xs"
          >
            <span class="font-medium text-n-slate-12">
              {{ userFor(pinned.userId)?.name }}
            </span>
            <span class="truncate text-n-slate-11">{{ pinned.body }}</span>
          </div>
        </div>

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
              :can-delete-any="isAdministrator"
              @reply="value => (replyTo = value)"
              @react="react"
              @pin="togglePin"
              @delete="askDelete"
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

        <p
          v-if="activeRoom.canPost === false"
          class="flex items-center gap-2 px-4 py-3 m-0 text-sm border-t text-n-slate-11 border-n-weak"
        >
          <Icon icon="i-lucide-lock" class="flex-shrink-0 size-4" />
          {{ t('INTERNAL_CHAT.COMPOSER.READ_ONLY') }}
        </p>

        <ChatComposer
          v-else
          :channel-id="activeRoomId"
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

    <!-- Irmao da conversa, e nao sobreposto a ela: a lista de membros e para ser
         consultada ENQUANTO se le o canal. Escondido no celular, onde nao cabem
         duas colunas. -->
    <ChannelMembersPanel
      v-if="membersOpen && activeRoom && isChannel"
      class="hidden lg:flex"
      :room="activeRoom"
      :users="users"
      @close="membersOpen = false"
    />

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

    <ManageMembersDialog
      ref="manageMembersDialog"
      :users="users"
      :current-user-id="currentUserId"
      @add="addMember"
      @remove="removeMember"
    />

    <EditChannelDialog
      ref="editChannelDialog"
      :users="users"
      @save="saveChannel"
    />

    <!-- `alert` porque a pergunta e sobre algo que nao tem volta: o dialogo se
         apresenta como aviso, nao como formulario. -->
    <Dialog
      ref="deleteDialog"
      type="alert"
      width="sm"
      :title="t('INTERNAL_CHAT.MESSAGE.DELETE_TITLE')"
      :description="t('INTERNAL_CHAT.MESSAGE.DELETE_CONFIRM')"
      :confirm-button-label="t('INTERNAL_CHAT.MESSAGE.DELETE')"
      @confirm="confirmDelete"
    />

    <Dialog
      ref="deleteChannelDialog"
      type="alert"
      width="sm"
      :title="t('INTERNAL_CHAT.HEADER.DELETE_CHANNEL')"
      :description="t('INTERNAL_CHAT.HEADER.DELETE_CHANNEL_CONFIRM')"
      :confirm-button-label="t('INTERNAL_CHAT.HEADER.DELETE_CHANNEL')"
      @confirm="deleteChannel"
    />

    <ImageLightbox
      :attachment="lightboxAttachment"
      @close="lightboxAttachment = null"
    />
  </div>
</template>
