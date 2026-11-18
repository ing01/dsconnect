<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MessageList from './MessageList.vue';
import CaptainAssistant from 'dashboard/api/captain/assistant';

const { assistantId } = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const messages = ref([]);
const newMessage = ref('');
const isLoading = ref(false);

// So' pro teste no Playground - a conversa real nunca passa por aqui, ela
// anexa a imagem como Message de verdade (ver Captain::OpenAiMessageBuilderService).
const MAX_PLAYGROUND_IMAGES = 3;
const MAX_PLAYGROUND_IMAGE_BYTES = 6 * 1024 * 1024;
const pendingImages = ref([]);
const fileInput = ref(null);

const readFileAsDataUrl = file =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

const openFilePicker = () => fileInput.value?.click();

const handleFilesSelected = async event => {
  const files = Array.from(event.target.files || []);
  event.target.value = '';
  if (!files.length) return;

  if (pendingImages.value.length + files.length > MAX_PLAYGROUND_IMAGES) {
    useAlert(t('CAPTAIN.PLAYGROUND.TOO_MANY_IMAGES', { max: MAX_PLAYGROUND_IMAGES }));
    return;
  }

  const oversized = files.find(file => file.size > MAX_PLAYGROUND_IMAGE_BYTES);
  if (oversized) {
    useAlert(t('CAPTAIN.PLAYGROUND.IMAGE_TOO_LARGE'));
    return;
  }

  const readImages = await Promise.all(
    files.map(async file => ({
      name: file.name,
      dataUrl: await readFileAsDataUrl(file),
    }))
  );
  pendingImages.value.push(...readImages);
};

const removePendingImage = index => {
  pendingImages.value.splice(index, 1);
};

const formatMessagesForApi = () => {
  return messages.value.map(message => {
    const payload = {
      role: message.sender,
      content: message.content,
    };

    if (message.sender === 'assistant' && message.agentName) {
      payload.agent_name = message.agentName;
    }

    return payload;
  });
};

const resetConversation = () => {
  messages.value = [];
  newMessage.value = '';
  pendingImages.value = [];
};

// Watch for assistant ID changes and reset conversation
watch(
  () => assistantId,
  (newId, oldId) => {
    if (oldId && newId !== oldId) {
      resetConversation();
    }
  }
);

const sendMessage = async () => {
  const hasImages = pendingImages.value.length > 0;
  if ((!newMessage.value.trim() && !hasImages) || isLoading.value) return;

  const userMessage = {
    content: newMessage.value,
    images: pendingImages.value.map(image => image.dataUrl),
    sender: 'user',
    timestamp: new Date().toISOString(),
  };
  messages.value.push(userMessage);
  const currentMessage = newMessage.value;
  const currentImages = userMessage.images;
  newMessage.value = '';
  pendingImages.value = [];

  try {
    isLoading.value = true;
    const { data } = await CaptainAssistant.playground({
      assistantId,
      messageContent: currentMessage,
      messageHistory: formatMessagesForApi(),
      images: currentImages,
    });

    messages.value.push({
      content: data.response,
      sender: 'assistant',
      agentName: data.agent_name,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    messages.value.pop();
    newMessage.value = currentMessage;
    pendingImages.value = currentImages.map(dataUrl => ({ dataUrl, name: '' }));
    useAlert(
      error?.response?.data?.error || t('CAPTAIN.PLAYGROUND.SEND_ERROR')
    );
    // eslint-disable-next-line no-console
    console.error('Error getting assistant response:', error);
  } finally {
    isLoading.value = false;
  }
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  sendMessage();
};
</script>

<template>
  <div
    class="flex flex-col h-full rounded-xl border py-6 border-n-weak text-n-slate-11"
  >
    <div class="mb-8 px-6">
      <div class="flex justify-between items-center mb-1">
        <h3 class="text-lg font-medium">
          {{ t('CAPTAIN.PLAYGROUND.HEADER') }}
        </h3>
        <NextButton
          ghost
          sm
          slate
          icon="i-lucide-rotate-ccw"
          @click="resetConversation"
        />
      </div>
      <p class="text-sm text-n-slate-11">
        {{ t('CAPTAIN.PLAYGROUND.DESCRIPTION') }}
      </p>
    </div>

    <MessageList :messages="messages" :is-loading="isLoading" />

    <div
      v-if="pendingImages.length"
      class="flex flex-wrap gap-2 mx-6 mb-2"
    >
      <div
        v-for="(image, index) in pendingImages"
        :key="image.dataUrl"
        class="relative"
      >
        <img
          :src="image.dataUrl"
          :alt="image.name"
          class="size-12 rounded-md object-cover outline outline-1 outline-n-weak"
        />
        <button
          type="button"
          class="absolute -top-1.5 -right-1.5 flex items-center justify-center size-4 rounded-full bg-n-slate-12 text-n-slate-1"
          :title="t('CAPTAIN.PLAYGROUND.REMOVE_IMAGE')"
          @click="removePendingImage(index)"
        >
          <span class="i-lucide-x size-2.5" />
        </button>
      </div>
    </div>

    <div
      class="flex items-center mx-6 bg-n-background outline outline-1 outline-n-weak rounded-xl p-3"
    >
      <input
        ref="fileInput"
        type="file"
        accept="image/*"
        multiple
        class="hidden"
        @change="handleFilesSelected"
      />
      <NextButton
        ghost
        sm
        slate
        icon="i-lucide-image-plus"
        :title="t('CAPTAIN.PLAYGROUND.ATTACH_IMAGE')"
        @click="openFilePicker"
      />
      <input
        v-model="newMessage"
        class="flex-1 bg-transparent border-none focus:outline-none text-sm mb-0 text-n-slate-12 placeholder:text-n-slate-10"
        :placeholder="t('CAPTAIN.PLAYGROUND.MESSAGE_PLACEHOLDER')"
        @keydown.enter.exact="handleEnterKey"
      />
      <NextButton
        ghost
        sm
        :disabled="!newMessage.trim() && !pendingImages.length"
        icon="i-lucide-send"
        @click="sendMessage"
      />
    </div>

    <p class="text-xs text-n-slate-11 pt-2 text-center">
      {{ t('CAPTAIN.PLAYGROUND.CREDIT_NOTE') }}
    </p>
  </div>
</template>
