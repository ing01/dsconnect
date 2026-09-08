<script setup>
import { computed, defineAsyncComponent, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { DirectUpload } from 'activestorage';
import { useAlert } from 'dashboard/composables';
import { setDirectUploadAuthHeaders } from 'dashboard/helper/directUploadsHelper';
import InternalChatAPI from 'dashboard/api/internalChat';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  // O upload e autorizado por sala, entao o composer precisa saber em qual esta.
  channelId: { type: [Number, String], default: null },
  users: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  replyTo: { type: Object, default: null },
  replyAuthor: { type: Object, default: null },
  // Anexos ainda não são gravados no servidor. Enquanto isso, o botão fica
  // desabilitado em vez de aceitar um arquivo que sumiria ao recarregar.
  allowAttachments: { type: Boolean, default: true },
});

const emit = defineEmits(['send', 'cancelReply']);

// O mesmo seletor da caixa de resposta das Conversations: tem busca, categorias
// e a lista completa, no lugar de um punhado de emojis fixos. Assincrono porque
// carrega a tabela inteira de emojis, que nao precisa entrar no bundle da tela.
const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const { t } = useI18n();

const body = ref('');
const textareaRef = ref(null);
const attachMenuOpen = ref(false);
const emojiOpen = ref(false);
const pendingAttachments = ref([]);
const isUploading = ref(false);
const fileInput = ref(null);
const acceptedTypes = ref('');

const MAXIMUM_SIZE_MB = 25;
const MAXIMUM_FILES = 10;

// Menção: digitar `@` abre a lista, e escolher alguém completa o nome inteiro.
const mentionQuery = ref(null);

const mentionMatches = computed(() => {
  if (mentionQuery.value === null) return [];

  const term = mentionQuery.value.toLowerCase();
  return props.users
    .filter(user => user.name.toLowerCase().includes(term))
    .slice(0, 5);
});

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

// No ponto do cursor, e nao no fim: com o texto ja escrito, acrescentar ao
// final punha o emoji longe de onde a pessoa estava digitando.
const insertEmoji = emoji => {
  const field = textareaRef.value;
  const at = field?.selectionStart ?? body.value.length;
  body.value = body.value.slice(0, at) + emoji + body.value.slice(at);

  nextTick(() => {
    field?.focus();
    const cursor = at + emoji.length;
    field?.setSelectionRange(cursor, cursor);
  });
};

// O arquivo vai direto do navegador para o storage. O que volta e o signed id
// do blob, e e so ele que acompanha a mensagem - os bytes nunca passam pela
// aplicacao, que e o que faz isso continuar valendo com o bucket na nuvem.
const humanSize = bytes => {
  const mb = bytes / (1024 * 1024);
  return mb >= 1
    ? `${mb.toFixed(1)} MB`
    : `${Math.max(1, Math.round(bytes / 1024))} KB`;
};

const pickFiles = kind => {
  attachMenuOpen.value = false;
  acceptedTypes.value = kind === 'image' ? 'image/*' : '';
  nextTick(() => fileInput.value?.click());
};

const uploadOne = file =>
  new Promise(resolve => {
    const upload = new DirectUpload(
      file,
      InternalChatAPI.directUploadUrl(props.channelId),
      { directUploadWillCreateBlobWithXHR: setDirectUploadAuthHeaders }
    );

    upload.create((error, blob) => {
      if (error) {
        useAlert(
          t('INTERNAL_CHAT.COMPOSER.UPLOAD_FAILED', { name: file.name })
        );
        resolve(null);
        return;
      }

      const isImage = file.type.startsWith('image/');
      resolve({
        signedId: blob.signed_id,
        name: file.name,
        size: humanSize(file.size),
        kind: isImage ? 'image' : 'file',
        // Mostra a imagem escolhida antes de a mensagem existir, sem ida ao
        // servidor. O endereco e liberado quando o anexo sai da lista.
        preview: isImage ? URL.createObjectURL(file) : null,
      });
    });
  });

const withinSizeLimit = file => {
  if (file.size <= MAXIMUM_SIZE_MB * 1024 * 1024) return true;

  useAlert(
    t('INTERNAL_CHAT.COMPOSER.FILE_TOO_LARGE', {
      name: file.name,
      size: MAXIMUM_SIZE_MB,
    })
  );
  return false;
};

const onFilesChosen = async event => {
  const chosen = Array.from(event.target.files || []);
  event.target.value = '';
  if (!chosen.length) return;

  if (pendingAttachments.value.length + chosen.length > MAXIMUM_FILES) {
    useAlert(
      t('INTERNAL_CHAT.COMPOSER.TOO_MANY_FILES', { count: MAXIMUM_FILES })
    );
    return;
  }

  const accepted = chosen.filter(withinSizeLimit);
  if (!accepted.length) return;

  isUploading.value = true;
  try {
    const uploaded = await Promise.all(accepted.map(uploadOne));
    pendingAttachments.value.push(...uploaded.filter(Boolean));
  } finally {
    isUploading.value = false;
  }
};

const removeAttachment = index => {
  const [removed] = pendingAttachments.value.splice(index, 1);
  if (removed?.preview) URL.revokeObjectURL(removed.preview);
};

const clearAttachments = () => {
  pendingAttachments.value.forEach(item => {
    if (item.preview) URL.revokeObjectURL(item.preview);
  });
  pendingAttachments.value = [];
};

// Nao envia no meio de um upload: a mensagem sairia sem o arquivo que a pessoa
// acabou de escolher.
const canSend = computed(
  () =>
    !isUploading.value &&
    (!!body.value.trim() || pendingAttachments.value.length > 0)
);

const send = () => {
  if (!canSend.value) return;

  emit('send', {
    body: body.value.trim(),
    attachments: pendingAttachments.value.map(item => item.signedId),
    replyTo: props.replyTo?.id || null,
  });

  body.value = '';
  clearAttachments();
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

    <!-- Anexos escolhidos, ja no storage, aguardando a mensagem -->
    <div v-if="pendingAttachments.length" class="flex flex-wrap gap-2">
      <div
        v-for="(item, index) in pendingAttachments"
        :key="item.signedId"
        class="flex items-center gap-2 py-1 pl-1 pr-1.5 text-xs rounded-md bg-n-solid-2 text-n-slate-11 max-w-64"
      >
        <img
          v-if="item.preview"
          :src="item.preview"
          :alt="item.name"
          class="object-cover flex-shrink-0 rounded size-8"
        />
        <Icon
          v-else
          icon="i-lucide-paperclip"
          class="flex-shrink-0 mx-1 size-3.5"
        />
        <span class="min-w-0 truncate grow">
          {{ item.name }} · {{ item.size }}
        </span>
        <button
          type="button"
          class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
          :title="t('INTERNAL_CHAT.COMPOSER.REMOVE_ATTACHMENT')"
          @click="removeAttachment(index)"
        >
          <Icon icon="i-lucide-x" class="size-3.5" />
        </button>
      </div>
    </div>

    <div
      v-if="isUploading"
      class="flex items-center gap-2 text-xs text-n-slate-11"
    >
      <Icon icon="i-lucide-loader-circle" class="animate-spin size-3.5" />
      {{ t('INTERNAL_CHAT.COMPOSER.UPLOADING') }}
    </div>

    <!-- Um so input serve as duas entradas do menu; o que muda e o filtro. -->
    <input
      ref="fileInput"
      type="file"
      multiple
      class="hidden"
      :accept="acceptedTypes"
      @change="onFilesChosen"
    />

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
              @click="pickFiles('image')"
            >
              <Icon icon="i-lucide-image" class="size-4 text-n-slate-11" />
              {{ t('INTERNAL_CHAT.COMPOSER.ATTACH_IMAGE') }}
            </button>
            <button
              type="button"
              class="flex items-center gap-2 px-3 py-1.5 text-sm text-start text-n-slate-12 hover:bg-n-alpha-2"
              @click="pickFiles('file')"
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

          <!-- Ancorado a direita: o painel tem 22rem e o botao fica junto ao
               Enviar, entao alinhado a esquerda ele sairia da tela. -->
          <EmojiIconPicker
            v-if="emojiOpen"
            mode="emoji"
            class="!top-auto !bottom-full mb-1.5 ltr:right-0 rtl:left-0"
            @select="insertEmoji($event.value)"
          />
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
