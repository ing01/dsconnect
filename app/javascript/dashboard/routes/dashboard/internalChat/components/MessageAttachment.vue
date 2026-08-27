<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  attachment: { type: Object, required: true },
});

const emit = defineEmits(['openImage']);

const isImage = computed(() => props.attachment.kind === 'image');

// Sem host externo: a política de conteúdo do produto bloqueia imagem de fora,
// e o protótipo não deve depender de rede para mostrar um anexo. O preview é
// um bloco desenhado com o nome do arquivo.
const previewStyle = computed(() => ({
  background: `linear-gradient(135deg, ${props.attachment.color || '#3f5c78'}, #23303d)`,
}));

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
    <span
      class="flex items-center justify-center h-40 text-xs text-white/80"
      :style="previewStyle"
    >
      {{ attachment.name }}
    </span>
    <span
      class="flex items-center justify-between gap-2 px-2.5 py-1.5 text-xs bg-n-solid-2 text-n-slate-11"
    >
      <span class="truncate">{{ attachment.name }}</span>
      <span class="flex-shrink-0">{{ attachment.size }}</span>
    </span>
  </button>

  <div
    v-else
    class="flex items-center gap-2.5 mt-1.5 px-2.5 py-2 rounded-lg border border-n-weak bg-n-solid-2 w-full max-w-[20rem]"
  >
    <Icon :icon="fileIcon" class="flex-shrink-0 size-4 text-n-slate-11" />
    <span class="flex flex-col min-w-0">
      <span class="text-sm truncate text-n-slate-12">{{
        attachment.name
      }}</span>
      <span class="text-xs text-n-slate-10">{{ attachment.size }}</span>
    </span>
  </div>
</template>
