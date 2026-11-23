<script setup>
import { ref, onMounted } from 'vue';
import Icon from 'next/icon/Icon.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';
import { useMessageContext } from '../provider.js';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});
const showGallery = ref(false);

const { filteredCurrentChatAttachments } = useMessageContext();

// A mesma protecao do bubbles/Image.vue (imagem unica, sem legenda): sem
// isto, uma falha passageira de rede no PRIMEIRO carregamento travava o chip
// em "Falha no carregamento" para sempre, mesmo a URL sendo valida - e toda
// imagem enviada COM legenda (como a do chat da Area do Cliente) cai aqui,
// nao no bubbles/Image.vue.
const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry();

onMounted(() => {
  if (props.attachment?.dataUrl) loadWithRetry(props.attachment.dataUrl);
});

const handleError = () => {
  hasError.value = true;
};
</script>

<template>
  <div
    class="size-[72px] overflow-hidden contain-content rounded-xl cursor-pointer"
    @click="showGallery = true"
  >
    <div
      v-if="hasError"
      class="flex flex-col items-center justify-center gap-1 text-xs text-center rounded-lg size-full bg-n-alpha-1 text-n-slate-11"
    >
      <Icon icon="i-lucide-circle-off" class="text-n-slate-11" />
      {{ $t('COMPONENTS.MEDIA.LOADING_FAILED') }}
    </div>
    <img
      v-else-if="isLoaded"
      class="object-cover w-full h-full skip-context-menu"
      :src="attachment.dataUrl"
    />
  </div>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleError"
    @close="() => (showGallery = false)"
  />
</template>
