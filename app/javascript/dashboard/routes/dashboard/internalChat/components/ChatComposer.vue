<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  users: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  replyTo: { type: Object, default: null },
  replyAuthor: { type: Object, default: null },
  // Anexos ainda não são gravados no servidor. Enquanto isso, o botão fica
  // desabilitado em vez de aceitar um arquivo que sumiria ao recarregar.
  allowAttachments: { type: Boolean, default: true },
});

const emit = defineEmits(['send', 'cancelReply']);

const { t } = useI18n();

const body = ref('');
const textareaRef = ref(null);
const attachMenuOpen = ref(false);
const emojiOpen = ref(false);
const pendingAttachment = ref(null);

// Menção: digitar `@` abre a lista, e escolher alguém completa o nome inteiro.
const mentionQuery = ref(null);

const mentionMatches = computed(() => {
  if (mentionQuery.value === null) return [];

  const term = mentionQuery.value.toLowerCase();
  return props.users
    .filter(user => user.name.toLowerCase().includes(term))
    .slice(0, 5);
});

const EMOJIS = ['👍', '❤️', '😂', '✅', '🎉', '🙏', '👀', '🚀'];

const onInput = () => {
  const upToCursor = body.value.slice(
    0,
    textareaRef.value?.selectionStart ?? 0
  );
  const match = upToCursor.match(/@([\p{L}\s]{0,20})$/u);
  mentionQuery.value = match ? match[1] : null;
};

const applyMention = user => {
  const cursor = textareaRef.value?.selectionStart ?? body.value.length;
  const before = body.value
    .slice(0, cursor)
    .replace(/@([\p{L}\s]{0,20})$/u, '');
  body.value = `${before}@${user.name} ${body.value.slice(cursor)}`;
  mentionQuery.value = null;
  nextTick(() => textareaRef.value?.focus());
};

// Anexo simulado: o protótipo não sobe arquivo nenhum, só registra o que foi
// escolhido para que a mensagem apareça com o preview certo.
const attachMock = kind => {
  pendingAttachment.value =
    kind === 'image'
      ? {
          kind: 'image',
          name: 'captura-de-tela.png',
          size: '284 KB',
          color: '#3f5c78',
        }
      : { kind: 'file', name: 'relatorio.pdf', size: '1.2 MB' };
  attachMenuOpen.value = false;
};

const canSend = computed(
  () => !!body.value.trim() || !!pendingAttachment.value
);

const send = () => {
  if (!canSend.value) return;

  emit('send', {
    body: body.value.trim(),
    attachment: pendingAttachment.value,
    replyTo: props.replyTo?.id || null,
  });

  body.value = '';
  pendingAttachment.value = null;
  mentionQuery.value = null;
};

// Enter envia, Shift+Enter quebra linha - o que se espera de um mensageiro.
const onKeydown = event => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    send();
  }
};
</script>

<template>
  <div
    class="flex flex-col gap-2 px-4 py-3 border-t border-n-weak bg-n-solid-1"
  >
    <!-- Contexto da resposta, acima do campo -->
    <div
      v-if="replyTo"
      class="flex items-center gap-2 px-2.5 py-1.5 text-xs rounded-md bg-n-solid-2 text-n-slate-11"
    >
      <Icon icon="i-lucide-corner-up-right" class="flex-shrink-0 size-3.5" />
      <span class="min-w-0 truncate grow">
        {{
          t('INTERNAL_CHAT.COMPOSER.REPLYING_TO', { name: replyAuthor?.name })
        }}
        <span class="text-n-slate-10">
          {{ t('INTERNAL_CHAT.COMPOSER.QUOTED', { text: replyTo.body }) }}
        </span>
      </span>
      <button
        type="button"
        class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
        :title="t('INTERNAL_CHAT.COMPOSER.CANCEL_REPLY')"
        @click="emit('cancelReply')"
      >
        <Icon icon="i-lucide-x" class="size-3.5" />
      </button>
    </div>

    <!-- Anexo escolhido, ainda não enviado -->
    <div
      v-if="pendingAttachment"
      class="flex items-center gap-2 px-2.5 py-1.5 text-xs rounded-md bg-n-solid-2 text-n-slate-11"
    >
      <Icon
        :icon="
          pendingAttachment.kind === 'image'
            ? 'i-lucide-image'
            : 'i-lucide-paperclip'
        "
        class="flex-shrink-0 size-3.5"
      />
      <span class="min-w-0 truncate grow">
        {{ pendingAttachment.name }} · {{ pendingAttachment.size }}
      </span>
      <button
        type="button"
        class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
        :title="t('INTERNAL_CHAT.COMPOSER.REMOVE_ATTACHMENT')"
        @click="pendingAttachment = null"
      >
        <Icon icon="i-lucide-x" class="size-3.5" />
      </button>
    </div>

    <div class="relative flex items-end gap-2">
      <!-- Menu de anexos -->
      <OnClickOutside @trigger="attachMenuOpen = false">
        <div class="relative">
          <button
            type="button"
            class="p-2 rounded-md text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-40 disabled:cursor-not-allowed"
            :disabled="!allowAttachments"
            :title="
              allowAttachments
                ? t('INTERNAL_CHAT.COMPOSER.ATTACH')
                : t('INTERNAL_CHAT.COMPOSER.ATTACH_SOON')
            "
            @click="attachMenuOpen = !attachMenuOpen"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
          </button>

          <div
            v-if="attachMenuOpen"
            class="absolute z-20 flex flex-col w-48 py-1 border rounded-md shadow-md bottom-full mb-1 border-n-weak bg-n-solid-1"
          >
            <button
              type="button"
              class="flex items-center gap-2 px-3 py-1.5 text-sm text-start text-n-slate-12 hover:bg-n-alpha-2"
              @click="attachMock('image')"
            >
              <Icon icon="i-lucide-image" class="size-4 text-n-slate-11" />
              {{ t('INTERNAL_CHAT.COMPOSER.ATTACH_IMAGE') }}
            </button>
            <button
              type="button"
              class="flex items-center gap-2 px-3 py-1.5 text-sm text-start text-n-slate-12 hover:bg-n-alpha-2"
              @click="attachMock('file')"
            >
              <Icon icon="i-lucide-paperclip" class="size-4 text-n-slate-11" />
              {{ t('INTERNAL_CHAT.COMPOSER.ATTACH_FILE') }}
            </button>
          </div>
        </div>
      </OnClickOutside>

      <div class="relative min-w-0 grow">
        <!-- Sugestões de menção -->
        <div
          v-if="mentionMatches.length"
          class="absolute z-20 flex flex-col w-56 py-1 border rounded-md shadow-md bottom-full mb-1 border-n-weak bg-n-solid-1"
        >
          <button
            v-for="user in mentionMatches"
            :key="user.id"
            type="button"
            class="flex items-center justify-between gap-2 px-3 py-1.5 text-sm text-start hover:bg-n-alpha-2"
            @click="applyMention(user)"
          >
            <span class="truncate text-n-slate-12">{{ user.name }}</span>
            <span class="flex-shrink-0 text-xs text-n-slate-10">{{
              user.role
            }}</span>
          </button>
        </div>

        <textarea
          ref="textareaRef"
          v-model="body"
          rows="1"
          class="w-full py-2 mb-0 text-sm resize-none max-h-32"
          :placeholder="placeholder || t('INTERNAL_CHAT.COMPOSER.PLACEHOLDER')"
          @input="onInput"
          @keydown="onKeydown"
        />
      </div>

      <OnClickOutside @trigger="emojiOpen = false">
        <div class="relative">
          <button
            type="button"
            class="p-2 rounded-md text-n-slate-11 hover:bg-n-alpha-2"
            :title="t('INTERNAL_CHAT.COMPOSER.EMOJI')"
            @click="emojiOpen = !emojiOpen"
          >
            <Icon icon="i-lucide-smile" class="size-4" />
          </button>

          <div
            v-if="emojiOpen"
            class="absolute z-20 grid grid-cols-4 gap-0.5 p-1.5 border rounded-md shadow-md bottom-full end-0 mb-1 border-n-weak bg-n-solid-1"
          >
            <button
              v-for="emoji in EMOJIS"
              :key="emoji"
              type="button"
              class="p-1 text-base rounded hover:bg-n-alpha-2"
              @click="body += emoji"
            >
              {{ emoji }}
            </button>
          </div>
        </div>
      </OnClickOutside>

      <Button
        :label="t('INTERNAL_CHAT.COMPOSER.SEND')"
        :disabled="!canSend"
        @click="send"
      />
    </div>
  </div>
</template>
