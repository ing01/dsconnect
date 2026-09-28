<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

// Mesmo limite validado no backend (Suggestion::MAXIMUM_ATTACHMENT_SIZE) -
// checar aqui evita o upload inteiro so pra descobrir que o arquivo passa do
// tamanho.
const MAX_SIZE = 20 * 1024 * 1024;
const ACCEPTED_PREFIXES = ['image/', 'video/'];

const input = ref(null);
// Miniatura gerada uma vez por arquivo e reaproveitada nos re-renders - um
// WeakMap some sozinho quando o arquivo e removido, sem precisar revogar a
// URL manualmente.
const previewCache = new WeakMap();

const isAccepted = file =>
  ACCEPTED_PREFIXES.some(prefix => file.type.startsWith(prefix));
const isImage = file => file.type.startsWith('image/');

const add = event => {
  const chosen = Array.from(event.target.files || []);
  const accepted = [];

  chosen.forEach(file => {
    if (!isAccepted(file)) {
      useAlert(t('SUGGESTIONS.ATTACHMENTS.INVALID_TYPE', { name: file.name }));
    } else if (file.size > MAX_SIZE) {
      useAlert(t('SUGGESTIONS.ATTACHMENTS.TOO_LARGE', { name: file.name }));
    } else {
      accepted.push(file);
    }
  });

  if (accepted.length) {
    emit('update:modelValue', [...props.modelValue, ...accepted]);
  }
  // Limpo pra escolher o mesmo arquivo de novo ainda disparar o `change`.
  event.target.value = '';
};

const remove = index => {
  emit(
    'update:modelValue',
    props.modelValue.filter((_file, position) => position !== index)
  );
};

const previewUrl = file => {
  if (!previewCache.has(file)) {
    previewCache.set(file, URL.createObjectURL(file));
  }
  return previewCache.get(file);
};

const formatSize = bytes => `${Math.max(1, Math.round(bytes / 1024))} KB`;
</script>

<template>
  <div class="flex flex-col gap-2 min-w-0">
    <input
      ref="input"
      type="file"
      multiple
      accept="image/*,video/*"
      class="hidden"
      @change="add"
    />
    <Button
      variant="faded"
      color="slate"
      size="sm"
      type="button"
      icon="i-lucide-image-plus"
      class="w-fit"
      :label="t('SUGGESTIONS.ATTACHMENTS.ADD')"
      @click="input?.click()"
    />

    <ul v-if="modelValue.length" class="flex flex-wrap gap-2 min-w-0">
      <li
        v-for="(file, index) in modelValue"
        :key="`${file.name}-${index}`"
        class="flex items-center max-w-[180px] gap-1.5 px-2 py-1 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-11"
      >
        <img
          v-if="isImage(file)"
          :src="previewUrl(file)"
          class="flex-shrink-0 object-cover rounded size-6"
        />
        <Icon v-else icon="i-lucide-video" class="flex-shrink-0 size-4" />
        <span class="truncate min-w-0" :title="file.name">{{ file.name }}</span>
        <span class="flex-shrink-0 text-n-slate-10">{{ formatSize(file.size) }}</span>
        <button
          type="button"
          class="flex-shrink-0 p-0.5 rounded hover:bg-n-alpha-2"
          :aria-label="t('SUGGESTIONS.ATTACHMENTS.REMOVE')"
          @click="remove(index)"
        >
          <Icon icon="i-lucide-x" class="size-3.5" />
        </button>
      </li>
    </ul>
  </div>
</template>
