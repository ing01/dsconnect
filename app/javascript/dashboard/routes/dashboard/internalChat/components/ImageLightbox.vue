<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  attachment: { type: Object, default: null },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

// Sempre o arquivo inteiro, nunca a miniatura: ampliar e justamente o motivo
// de abrir aqui.
const source = computed(() => props.attachment?.url);

const readableSize = computed(() => {
  const bytes = props.attachment?.byteSize;
  if (!bytes) return '';

  const mb = bytes / (1024 * 1024);
  return mb >= 1
    ? `${mb.toFixed(1)} MB`
    : `${Math.max(1, Math.round(bytes / 1024))} KB`;
});
</script>

<template>
  <div
    v-if="attachment"
    class="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 p-6 bg-black/70"
    role="dialog"
    aria-modal="true"
    @click.self="emit('close')"
    @keydown.esc="emit('close')"
  >
    <button
      type="button"
      class="absolute p-2 text-white rounded top-4 end-4 hover:bg-white/10"
      :title="t('INTERNAL_CHAT.IMAGE.CLOSE')"
      @click="emit('close')"
    >
      <Icon icon="i-lucide-x" class="size-5" />
    </button>

    <img
      :src="source"
      :alt="attachment.name"
      class="object-contain max-w-3xl rounded-lg max-h-[70vh]"
    />
    <p class="text-sm text-white/70">
      {{ attachment.name }} · {{ readableSize }}
    </p>
  </div>
</template>
