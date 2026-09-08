<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  attachment: { type: Object, required: true },
});

const emit = defineEmits(['openImage']);

const isImage = computed(() => props.attachment.kind === 'image');

// A miniatura quando existe, o arquivo inteiro quando nao: um SVG, por exemplo,
// nao passa pelo processador de imagem e volta sem `thumb`.
const previewSource = computed(
  () => props.attachment.thumb || props.attachment.url
);

const readableSize = computed(() => {
  const bytes = props.attachment.byteSize;
  if (!bytes) return '';

  const mb = bytes / (1024 * 1024);
  return mb >= 1
    ? `${mb.toFixed(1)} MB`
    : `${Math.max(1, Math.round(bytes / 1024))} KB`;
});

const fileIcon = computed(() =>
  props.attachment.name?.endsWith('.pdf')
    ? 'i-lucide-file-text'
    : 'i-lucide-paperclip'
);
</script>

<template>
  <button
    v-if="isImage"
    type="button"
    class="block mt-1.5 overflow-hidden rounded-lg border border-n-weak w-full max-w-[22rem] text-start hover:border-n-slate-7"
    @click="emit('openImage', attachment)"
  >
    <img
      :src="previewSource"
      :alt="attachment.name"
      loading="lazy"
      class="object-cover w-full h-40 bg-n-solid-2"
    />
    <span
      class="flex items-center justify-between gap-2 px-2.5 py-1.5 text-xs bg-n-solid-2 text-n-slate-11"
    >
      <span class="truncate">{{ attachment.name }}</span>
      <span class="flex-shrink-0">{{ readableSize }}</span>
    </span>
  </button>

  <!-- Arquivo que nao e imagem: abre em outra aba, servido pelo storage. -->
  <a
    v-else
    :href="attachment.url"
    target="_blank"
    rel="noopener noreferrer"
    class="flex items-center gap-2.5 mt-1.5 px-2.5 py-2 rounded-lg border border-n-weak bg-n-solid-2 w-full max-w-[20rem] hover:border-n-slate-7"
  >
    <Icon :icon="fileIcon" class="flex-shrink-0 size-4 text-n-slate-11" />
    <span class="flex flex-col min-w-0">
      <span class="text-sm truncate text-n-slate-12">{{
        attachment.name
      }}</span>
      <span class="text-xs text-n-slate-10">{{ readableSize }}</span>
    </span>
  </a>
</template>
