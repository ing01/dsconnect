<script setup>
import { computed, defineAsyncComponent, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { onClickOutside } from '@vueuse/core';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessageBody from './MessageBody.vue';
import MessageAttachment from './MessageAttachment.vue';
import { shortTime } from '../helpers/messageParser';
import { QUICK_REACTIONS } from '../helpers/constants';

const props = defineProps({
  message: { type: Object, required: true },
  author: { type: Object, default: null },
  users: { type: Array, default: () => [] },
  currentUserId: { type: Number, default: 0 },
  // Mensagem seguida do mesmo autor: repete só o texto, sem avatar nem nome.
  grouped: { type: Boolean, default: false },
  repliedMessage: { type: Object, default: null },
  repliedAuthor: { type: Object, default: null },
  // Administrador apaga qualquer mensagem, porque responde pelo que fica no Chat
  // da empresa. Quem decide isso e a tela de cima, que conhece o papel.
  canDeleteAny: { type: Boolean, default: false },
});

const emit = defineEmits([
  'reply',
  'react',
  'openImage',
  'openTicket',
  'pin',
  'delete',
  'markUnread',
  'edit',
]);

// O mesmo seletor do campo de mensagem. Assincrono pelo mesmo motivo: a tabela
// de emojis so' entra quando alguem abre.
const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const { t } = useI18n();

const time = computed(() => shortTime(props.message.createdAt));
const reactions = computed(() => props.message.reactions || []);
const isPinned = computed(() => !!props.message.pinnedAt);

const hasReacted = reaction => reaction.userIds.includes(props.currentUserId);

// Quem reagiu, para a dica ao passar o mouse. A propria pessoa vem primeiro, como
// "Você"; quem ja saiu da empresa continua contado, sem nome.
const reactionTitle = reaction => {
  const names = reaction.userIds
    .filter(id => id !== props.currentUserId)
    .map(
      id =>
        props.users.find(user => user.id === id)?.name ||
        t('INTERNAL_CHAT.MESSAGE.UNKNOWN_USER')
    );
  if (hasReacted(reaction)) names.unshift(t('INTERNAL_CHAT.MESSAGE.YOU'));

  const last = names.pop();
  const list = names.length
    ? t('INTERNAL_CHAT.MESSAGE.NAMES_LIST', { first: names.join(', '), last })
    : last;
  return t(
    names.length
      ? 'INTERNAL_CHAT.MESSAGE.REACTED_MANY'
      : 'INTERNAL_CHAT.MESSAGE.REACTED_ONE',
    { names: list, emoji: reaction.emoji }
  );
};

// O autor apaga a propria mensagem; o administrador apaga qualquer uma. A regra
// de verdade esta no servidor - isto so evita oferecer um botao que seria
// recusado.
const canDelete = computed(
  () => props.canDeleteAny || props.message.userId === props.currentUserId
);

// So' o autor edita - nem o administrador, que apagaria mas nao reescreve o que
// outra pessoa disse. Mesma regra do servidor.
const canEdit = computed(() => props.message.userId === props.currentUserId);

const isEditing = ref(false);
const draft = ref('');
const editInput = ref(null);

const draftRows = computed(() =>
  Math.min(Math.max(draft.value.split('\n').length, 2), 8)
);

const startEdit = async () => {
  draft.value = props.message.body || '';
  isEditing.value = true;
  await nextTick();
  const input = editInput.value;
  if (!input) return;
  input.focus();
  input.setSelectionRange(input.value.length, input.value.length);
};

const cancelEdit = () => {
  isEditing.value = false;
};

// Sai do modo de edicao na hora; se o servidor recusar, a tela de cima avisa e
// a mensagem continua com o texto de antes.
const saveEdit = () => {
  const content = draft.value.trim();
  const hasAttachments = (props.message.attachments || []).length > 0;
  if (!content && !hasAttachments) return;

  isEditing.value = false;
  if (content === (props.message.body || '').trim()) return;

  emit('edit', { messageId: props.message.id, content });
};

// Enter salva e Shift+Enter quebra linha, igual ao campo de envio; Esc desiste.
const onEditKeydown = event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    cancelEdit();
  } else if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    saveEdit();
  }
};

// O seletor abre fora da lista (Teleport), em posicao fixa: dentro dela seria
// cortado pela rolagem nas mensagens do topo e do fim.
const PICKER_WIDTH = 352;
const PICKER_HEIGHT = 320;
const GAP = 6;
const MARGIN = 8;

const pickerButton = ref(null);
const pickerPanel = ref(null);
const pickerStyle = ref(null);

const closePicker = () => {
  pickerStyle.value = null;
};

const togglePicker = () => {
  if (pickerStyle.value) {
    closePicker();
    return;
  }
  const rect = pickerButton.value.getBoundingClientRect();
  const maxLeft = window.innerWidth - PICKER_WIDTH - MARGIN;
  const left = Math.max(MARGIN, Math.min(rect.right - PICKER_WIDTH, maxLeft));
  const fitsBelow =
    rect.bottom + GAP + PICKER_HEIGHT <= window.innerHeight - MARGIN;

  pickerStyle.value = {
    left: `${left}px`,
    ...(fitsBelow
      ? { top: `${rect.bottom + GAP}px` }
      : { bottom: `${window.innerHeight - rect.top + GAP}px` }),
  };
};

onClickOutside(pickerPanel, closePicker, { ignore: [pickerButton] });

const reactWith = emoji => {
  closePicker();
  emit('react', { messageId: props.message.id, emoji });
};

const isEdited = computed(() => !!props.message.editedAt);
const previousVersions = computed(() => props.message.previousVersions || []);
const showPrevious = ref(false);

const formatStamp = timestamp =>
  timestamp
    ? new Date(timestamp * 1000).toLocaleString([], {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '';

const editedTitle = computed(() =>
  t('INTERNAL_CHAT.MESSAGE.EDITED_AT', {
    time: formatStamp(props.message.editedAt),
  })
);

// A primeira versao guardada e' o texto original; as seguintes, edicoes
// intermediarias.
const versionLabel = (version, index) =>
  t('INTERNAL_CHAT.MESSAGE.VERSION_LABEL', {
    label: t(
      index === 0
        ? 'INTERNAL_CHAT.MESSAGE.ORIGINAL'
        : 'INTERNAL_CHAT.MESSAGE.PREVIOUS_VERSION'
    ),
    time: formatStamp(version.writtenAt),
  });
</script>

<template>
  <div
    class="group relative flex gap-2.5 px-4 hover:bg-n-alpha-1"
    :class="grouped ? 'py-0.5' : 'pt-3 pb-0.5'"
  >
    <!-- A calha do avatar fica reservada mesmo quando agrupado, para que o
         texto de todas as linhas do bloco fique alinhado. -->
    <div class="flex-shrink-0 w-8">
      <Avatar
        v-if="!grouped"
        :name="author?.name || '?'"
        :src="author?.thumbnail"
        :size="32"
      />
    </div>

    <div class="flex flex-col min-w-0 grow">
      <!-- Citação da mensagem respondida, acima da resposta. -->
      <button
        v-if="repliedMessage"
        type="button"
        class="flex items-center gap-1.5 mb-0.5 text-xs text-n-slate-10 text-start hover:text-n-slate-11"
      >
        <Icon icon="i-lucide-corner-up-right" class="flex-shrink-0 size-3" />
        <span class="font-medium">{{ repliedAuthor?.name }}</span>
        <span class="truncate max-w-[22rem]">{{ repliedMessage.body }}</span>
      </button>

      <div v-if="!grouped" class="flex items-baseline gap-2">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ author?.name }}
        </span>
        <span class="text-xs tabular-nums text-n-slate-10">{{ time }}</span>
        <span
          v-if="isPinned"
          class="flex items-center gap-0.5 text-xs text-n-amber-11"
        >
          <Icon icon="i-lucide-pin" class="size-3" />
          {{ t('INTERNAL_CHAT.MESSAGE.PINNED') }}
        </span>
      </div>

      <div v-if="isEditing" class="flex flex-col gap-1 mt-0.5">
        <textarea
          ref="editInput"
          v-model="draft"
          :rows="draftRows"
          class="w-full p-2 mb-0 text-sm leading-relaxed border rounded-md resize-y border-n-weak bg-n-solid-2 text-n-slate-12 focus:border-n-brand"
          :aria-label="t('INTERNAL_CHAT.MESSAGE.EDIT')"
          @keydown="onEditKeydown"
        />
        <div class="flex items-center gap-3 text-xs text-n-slate-10">
          <span>{{ t('INTERNAL_CHAT.MESSAGE.EDIT_HINT') }}</span>
          <button
            type="button"
            class="hover:text-n-slate-12"
            @click="cancelEdit"
          >
            {{ t('INTERNAL_CHAT.MESSAGE.EDIT_CANCEL') }}
          </button>
          <button
            type="button"
            class="font-medium text-n-brand hover:underline"
            @click="saveEdit"
          >
            {{ t('INTERNAL_CHAT.MESSAGE.EDIT_SAVE') }}
          </button>
        </div>
      </div>

      <template v-else>
        <MessageBody
          v-if="message.body"
          :body="message.body"
          :users="users"
          @open-ticket="id => emit('openTicket', id)"
        />

        <!-- Editada: o aviso fica junto do texto, e o que estava escrito antes
             continua a um clique para qualquer pessoa da sala. -->
        <div
          v-if="isEdited"
          class="flex items-center gap-1.5 text-xs text-n-slate-10"
        >
          <span :title="editedTitle">
            {{ t('INTERNAL_CHAT.MESSAGE.EDITED') }}
          </span>
          <button
            v-if="previousVersions.length"
            type="button"
            class="underline hover:text-n-slate-12"
            @click="showPrevious = !showPrevious"
          >
            {{
              t(
                showPrevious
                  ? 'INTERNAL_CHAT.MESSAGE.HIDE_PREVIOUS'
                  : 'INTERNAL_CHAT.MESSAGE.SHOW_PREVIOUS'
              )
            }}
          </button>
        </div>

        <div
          v-if="isEdited && showPrevious"
          class="flex flex-col gap-1.5 py-1 mt-1 border-s-2 ps-2 border-n-weak"
        >
          <div
            v-for="(version, index) in previousVersions"
            :key="index"
            class="text-xs"
          >
            <span class="font-medium text-n-slate-11">
              {{ versionLabel(version, index) }}
            </span>
            <p
              class="m-0 break-words whitespace-pre-wrap text-n-slate-10 line-through decoration-n-slate-7"
            >
              {{ version.body || t('INTERNAL_CHAT.MESSAGE.EMPTY_VERSION') }}
            </p>
          </div>
        </div>
      </template>

      <MessageAttachment
        v-for="attachment in message.attachments || []"
        :key="attachment.id"
        :attachment="attachment"
        @open-image="chosen => emit('openImage', chosen)"
      />

      <div v-if="reactions.length" class="flex flex-wrap gap-1 mt-1.5">
        <button
          v-for="reaction in reactions"
          :key="reaction.emoji"
          v-tooltip.top="reactionTitle(reaction)"
          type="button"
          data-testid="reaction"
          :aria-label="reactionTitle(reaction)"
          :aria-pressed="hasReacted(reaction)"
          class="flex items-center gap-1 px-1.5 py-0.5 text-xs rounded-full border"
          :class="
            hasReacted(reaction)
              ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
              : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-n-slate-7'
          "
          @click="
            emit('react', { messageId: message.id, emoji: reaction.emoji })
          "
        >
          <span>{{ reaction.emoji }}</span>
          <span class="tabular-nums">{{ reaction.userIds.length }}</span>
        </button>
      </div>
    </div>

    <!-- Ações da mensagem: aparecem no hover para não poluir a leitura. -->
    <div
      class="absolute z-10 items-center hidden gap-0.5 p-0.5 border rounded-md shadow-sm -top-3 end-4 border-n-weak bg-n-solid-1 group-hover:flex group-focus-within:flex"
      :class="{ '!flex': pickerStyle }"
    >
      <button
        v-for="emoji in QUICK_REACTIONS"
        :key="emoji"
        type="button"
        class="px-1 text-sm rounded hover:bg-n-alpha-2"
        :title="t('INTERNAL_CHAT.MESSAGE.REACT')"
        @click="emit('react', { messageId: message.id, emoji })"
      >
        {{ emoji }}
      </button>
      <button
        ref="pickerButton"
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-11"
        data-testid="open-reaction-picker"
        :title="t('INTERNAL_CHAT.MESSAGE.MORE_REACTIONS')"
        :aria-label="t('INTERNAL_CHAT.MESSAGE.MORE_REACTIONS')"
        :aria-expanded="!!pickerStyle"
        @click="togglePicker"
      >
        <Icon icon="i-lucide-smile-plus" class="size-3.5" />
      </button>
      <button
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-11"
        :title="t('INTERNAL_CHAT.MESSAGE.REPLY')"
        @click="emit('reply', message)"
      >
        <Icon icon="i-lucide-reply" class="size-3.5" />
      </button>
      <button
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2"
        :class="isPinned ? 'text-n-amber-11' : 'text-n-slate-11'"
        :title="
          t(
            isPinned
              ? 'INTERNAL_CHAT.MESSAGE.UNPIN'
              : 'INTERNAL_CHAT.MESSAGE.PIN'
          )
        "
        @click="emit('pin', message.id)"
      >
        <Icon icon="i-lucide-pin" class="size-3.5" />
      </button>
      <button
        v-if="canEdit && !isEditing"
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-11"
        :title="t('INTERNAL_CHAT.MESSAGE.EDIT')"
        :aria-label="t('INTERNAL_CHAT.MESSAGE.EDIT')"
        @click="startEdit"
      >
        <Icon icon="i-lucide-pencil" class="size-3.5" />
      </button>
      <button
        v-if="message.userId !== currentUserId"
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-11"
        :title="t('INTERNAL_CHAT.MESSAGE.MARK_UNREAD')"
        :aria-label="t('INTERNAL_CHAT.MESSAGE.MARK_UNREAD')"
        @click="emit('markUnread', message)"
      >
        <Icon icon="i-lucide-mail" class="size-3.5" />
      </button>
      <button
        v-if="canDelete"
        type="button"
        class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-ruby-11"
        :title="t('INTERNAL_CHAT.MESSAGE.DELETE')"
        @click="emit('delete', message)"
      >
        <Icon icon="i-lucide-trash-2" class="size-3.5" />
      </button>
    </div>

    <Teleport to="body">
      <div
        v-if="pickerStyle"
        ref="pickerPanel"
        class="fixed z-50 w-[22rem]"
        :style="pickerStyle"
        data-testid="reaction-picker"
        @keydown.esc="closePicker"
      >
        <EmojiIconPicker
          mode="emoji"
          class="!static"
          @select="reactWith($event.value)"
        />
      </div>
    </Teleport>
  </div>
</template>
