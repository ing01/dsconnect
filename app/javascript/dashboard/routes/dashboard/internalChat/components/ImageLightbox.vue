<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useImageZoom } from 'dashboard/composables/useImageZoom';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  attachment: { type: Object, default: null },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const imageRef = ref(null);

// Os mesmos gestos da imagem do ticket: roda do mouse e duplo clique ampliam,
// arrastar move a imagem ampliada e os botoes giram.
const {
  imageWrapperStyle,
  imageStyle,
  onRotate,
  onZoom,
  onDoubleClickZoomImage,
  onWheelImageZoom,
  onMouseMove,
  onMouseLeave,
  onPanStart,
  resetZoomAndRotation,
} = useImageZoom(imageRef);

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

const caption = computed(() =>
  [props.attachment?.name, readableSize.value].filter(Boolean).join(' · ')
);

// Cada imagem abre sem o zoom e a rotacao da anterior.
watch(
  () => props.attachment,
  () => resetZoomAndRotation()
);

const onKeydown = event => {
  if (event.key === 'Escape' && props.attachment) emit('close');
};

onMounted(() => window.addEventListener('keydown', onKeydown));
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown));
</script>

<template>
  <div
    v-if="attachment"
    class="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 p-4 bg-black/80"
    role="dialog"
    aria-modal="true"
    @pointerdown.self="emit('close')"
  >
    <button
      type="button"
      class="absolute p-2 text-white rounded top-4 end-4 hover:bg-white/10"
      :title="t('INTERNAL_CHAT.IMAGE.CLOSE')"
      @click="emit('close')"
    >
      <Icon icon="i-lucide-x" class="size-5" />
    </button>

    <div
      class="flex items-center gap-1 px-2 py-1 rounded-lg bg-black/40"
      @pointerdown.stop
    >
      <Button
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-zoom-out"
        class="!text-white"
        :aria-label="t('INTERNAL_CHAT.IMAGE.ZOOM_OUT')"
        :title="t('INTERNAL_CHAT.IMAGE.ZOOM_OUT')"
        @click="onZoom(-0.2)"
      />
      <Button
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-zoom-in"
        class="!text-white"
        :aria-label="t('INTERNAL_CHAT.IMAGE.ZOOM_IN')"
        :title="t('INTERNAL_CHAT.IMAGE.ZOOM_IN')"
        @click="onZoom(0.2)"
      />
      <Button
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-rotate-ccw"
        class="!text-white"
        :aria-label="t('INTERNAL_CHAT.IMAGE.ROTATE_LEFT')"
        :title="t('INTERNAL_CHAT.IMAGE.ROTATE_LEFT')"
        @click="onRotate('counter-clockwise')"
      />
      <Button
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-rotate-cw"
        class="!text-white"
        :aria-label="t('INTERNAL_CHAT.IMAGE.ROTATE_RIGHT')"
        :title="t('INTERNAL_CHAT.IMAGE.ROTATE_RIGHT')"
        @click="onRotate('clockwise')"
      />
    </div>

    <div
      class="flex items-center justify-center max-w-full overflow-hidden"
      @pointerdown.self="emit('close')"
    >
      <div
        :style="imageWrapperStyle"
        class="flex items-center justify-center origin-center"
      >
        <img
          ref="imageRef"
          :src="source"
          :alt="attachment.name"
          :style="imageStyle"
          class="object-contain rounded-lg w-[92vw] h-[78vh] duration-100 ease-in-out transform select-none"
          draggable="false"
          @dragstart.prevent
          @dblclick.stop="onDoubleClickZoomImage"
          @wheel.prevent.stop="onWheelImageZoom"
          @pointerdown.stop="onPanStart"
          @mousemove="onMouseMove"
          @mouseleave="onMouseLeave"
        />
      </div>
    </div>
    <p class="text-sm text-white/70">{{ caption }}</p>
  </div>
</template>
