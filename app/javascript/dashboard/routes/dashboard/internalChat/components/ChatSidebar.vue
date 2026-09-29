<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { shortTime } from '../helpers/messageParser';
import { presenceDotClass } from '../helpers/presence';

const props = defineProps({
  directs: { type: Array, default: () => [] },
  channels: { type: Array, default: () => [] },
  users: { type: Array, default: () => [] },
  activeRoomId: { type: Number, default: null },
  // Editar o canal e decisao sobre o canal da empresa: so administrador.
  canEdit: { type: Boolean, default: false },
});

const emit = defineEmits([
  'select',
  'newConversation',
  'createChannel',
  'editChannel',
]);

const { t } = useI18n();

const query = ref('');

// O menu do botao direito. Guarda o canal e onde o cursor estava - o menu abre
// ali, e nao num canto fixo da tela.
const contextMenu = ref(null);

const openContextMenu = (event, channel) => {
  if (!props.canEdit) return;

  contextMenu.value = { channel, x: event.clientX, y: event.clientY };
};

const editFromContextMenu = () => {
  const channel = contextMenu.value?.channel;
  contextMenu.value = null;
  if (channel) emit('editChannel', channel);
};

const userFor = userId => props.users.find(user => user.id === userId);

// A previa da lista.
//
// `room.messages` so existe depois que a sala foi ABERTA - as mensagens sao
// buscadas ali, nao junto da lista. Lendo apenas dele, toda sala ainda nao aberta
// dizia "Sem mensagens ainda" mesmo estando cheia. `room.lastMessage` vem do
// servidor com a lista, e e a previa correta; o que ja esta carregado tem
// precedencia porque inclui o que acabou de chegar pelo tempo real.
const lastMessage = room =>
  room.messages[room.messages.length - 1] || room.lastMessage || null;

// Mensagem so com anexo nao tem texto, e uma linha vazia na lista nao diz nada.
const preview = room => {
  const message = lastMessage(room);
  if (!message) return t('INTERNAL_CHAT.SIDEBAR.NO_MESSAGES');

  const body = (message.body || '').trim();
  if (body) return body;

  return message.hasAttachments || message.attachments?.length
    ? t('INTERNAL_CHAT.SIDEBAR.ATTACHMENT_PREVIEW')
    : t('INTERNAL_CHAT.SIDEBAR.NO_MESSAGES');
};

// Conversas privadas e canais ficam em listas separadas de propósito: são
// coisas diferentes, e misturá-las é o que torna a barra lateral confusa.
const matches = text => text.toLowerCase().includes(query.value.toLowerCase());

const visibleDirects = computed(() =>
  props.directs.filter(direct => matches(userFor(direct.userId)?.name || ''))
);

const visibleChannels = computed(() =>
  props.channels.filter(channel => matches(channel.name))
);
</script>

<template>
  <aside
    class="flex flex-col h-full min-h-0 border-e border-n-weak bg-n-solid-1"
  >
    <div class="flex flex-col gap-2 p-3 border-b border-n-weak">
      <label class="relative flex items-center">
        <!-- Centrado pela metade da altura, e nao por um deslocamento fixo:
             assim a lupa acompanha o campo se a altura dele mudar. `block`
             tira o vao que o span herda da linha de base do texto. -->
        <Icon
          icon="i-lucide-search"
          class="absolute block -translate-y-1/2 pointer-events-none size-4 text-n-slate-10 start-2.5 top-1/2"
        />
        <!-- Os `!` sao necessarios: o seletor global de input em _base.scss
             (input[type] seguido de uma fila de :not) tem especificidade maior
             que a de qualquer classe utilitaria, entao o px-3 e o mb-4 dele
             venciam o recuo e a margem pedidos aqui. A altura vem do h-10 da
             mesma regra, e e sobre ela que a lupa se centraliza. -->
        <input
          v-model="query"
          type="search"
          class="w-full text-sm !mb-0 !ps-8"
          :placeholder="t('INTERNAL_CHAT.SIDEBAR.SEARCH')"
        />
      </label>
    </div>

    <div class="flex flex-col gap-4 py-3 overflow-y-auto grow">
      <!-- Conversas privadas -->
      <section class="flex flex-col gap-0.5">
        <header class="flex items-center justify-between gap-2 px-3 pb-1">
          <h3
            class="text-xs font-semibold tracking-wider uppercase text-n-slate-10"
          >
            {{ t('INTERNAL_CHAT.SIDEBAR.DIRECTS') }}
          </h3>
          <button
            type="button"
            class="p-0.5 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
            :title="t('INTERNAL_CHAT.SIDEBAR.NEW_CONVERSATION')"
            @click="emit('newConversation')"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
          </button>
        </header>

        <button
          v-for="direct in visibleDirects"
          :key="direct.id"
          type="button"
          class="flex items-center w-full gap-2.5 px-3 py-1.5 text-start"
          :class="
            direct.id === activeRoomId
              ? 'bg-n-alpha-2 text-n-slate-12'
              : 'hover:bg-n-alpha-1'
          "
          @click="emit('select', direct.id)"
        >
          <span class="relative flex-shrink-0">
            <Avatar :name="userFor(direct.userId)?.name || '?'" :size="28" />
            <span
              class="absolute bottom-0 size-2.5 rounded-full border-2 border-n-solid-1 end-0"
              :class="presenceDotClass(userFor(direct.userId)?.status)"
            />
          </span>

          <span class="flex flex-col min-w-0 grow">
            <span class="flex items-baseline justify-between gap-2">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ userFor(direct.userId)?.name }}
              </span>
              <span
                v-if="lastMessage(direct)"
                class="flex-shrink-0 text-xs tabular-nums text-n-slate-10"
              >
                {{ shortTime(lastMessage(direct).createdAt) }}
              </span>
            </span>
            <span class="text-xs truncate text-n-slate-10">
              {{ preview(direct) }}
            </span>
          </span>

          <span
            v-if="direct.unread"
            class="flex-shrink-0 min-w-[1.25rem] px-1 py-0.5 text-xs font-semibold text-center rounded-full text-white bg-n-blue-9 tabular-nums"
          >
            {{ direct.unread }}
          </span>
        </button>
      </section>

      <!-- Canais -->
      <section class="flex flex-col gap-0.5">
        <header class="flex items-center justify-between gap-2 px-3 pb-1">
          <h3
            class="text-xs font-semibold tracking-wider uppercase text-n-slate-10"
          >
            {{ t('INTERNAL_CHAT.SIDEBAR.CHANNELS') }}
          </h3>
          <button
            type="button"
            class="p-0.5 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
            :title="t('INTERNAL_CHAT.SIDEBAR.CREATE_CHANNEL')"
            @click="emit('createChannel')"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
          </button>
        </header>

        <button
          v-for="channel in visibleChannels"
          :key="channel.id"
          type="button"
          class="flex items-center w-full gap-2 px-3 py-1.5 text-start"
          :class="
            channel.id === activeRoomId
              ? 'bg-n-alpha-2 text-n-slate-12'
              : 'hover:bg-n-alpha-1'
          "
          @click="emit('select', channel.id)"
          @contextmenu.prevent="openContextMenu($event, channel)"
        >
          <Icon
            v-if="channel.pinned"
            icon="i-lucide-pin"
            class="flex-shrink-0 size-3.5 text-n-slate-10"
            :title="t('INTERNAL_CHAT.SIDEBAR.PINNED')"
          />
          <span v-else class="flex-shrink-0 text-sm text-n-slate-10">#</span>
          <!-- Canal em que esta pessoa nao escreve: um cadeado explica por que o
               campo de mensagem aparece desabilitado quando ela entrar. -->
          <Icon
            v-if="channel.canPost === false"
            icon="i-lucide-lock"
            class="flex-shrink-0 size-3.5 text-n-slate-10"
            :title="t('INTERNAL_CHAT.SIDEBAR.READ_ONLY')"
          />
          <span
            class="text-sm truncate grow"
            :class="
              channel.unread
                ? 'font-semibold text-n-slate-12'
                : 'text-n-slate-11'
            "
          >
            {{ channel.name }}
          </span>
          <span
            v-if="channel.unread"
            class="flex-shrink-0 min-w-[1.25rem] px-1 py-0.5 text-xs font-semibold text-center rounded-full text-white bg-n-blue-9 tabular-nums"
          >
            {{ channel.unread }}
          </span>
        </button>
      </section>
    </div>

    <!-- Fixo, e nao absoluto: a barra lateral rola, e um menu ancorado nela
         escaparia do lugar ao primeiro giro da roda. -->
    <OnClickOutside v-if="contextMenu" @trigger="contextMenu = null">
      <div
        class="fixed z-30 py-1 border rounded-lg shadow-md min-w-44 border-n-weak bg-n-solid-1"
        :style="{ top: `${contextMenu.y}px`, left: `${contextMenu.x}px` }"
      >
        <button
          type="button"
          class="flex items-center w-full gap-2 px-3 py-1.5 text-sm text-start text-n-slate-12 hover:bg-n-alpha-1"
          @click="editFromContextMenu"
        >
          <Icon icon="i-lucide-settings-2" class="size-4" />
          {{ t('INTERNAL_CHAT.SIDEBAR.EDIT_CHANNEL') }}
        </button>
      </div>
    </OnClickOutside>
  </aside>
</template>
