<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { downloadFile } from '@chatwoot/utils';
import { useImageZoom } from 'dashboard/composables/useImageZoom';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const dialogRef = ref(null);
const attachment = ref(null);
const imageRef = ref(null);
// As imagens do ticket, na ordem da lista: e' por elas que as setas e os botoes navegam.
const gallery = ref([]);
const isOpen = ref(false);

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

const open = (selected, images = []) => {
  resetZoomAndRotation();
  attachment.value = selected;
  gallery.value = images.length ? images : [selected];
  isOpen.value = true;
  dialogRef.value?.open();
};
const close = () => dialogRef.value?.close();
const onClosed = () => {
  isOpen.value = false;
  resetZoomAndRotation();
};

const currentIndex = computed(() =>
  gallery.value.findIndex(image => image.id === attachment.value?.id)
);
const hasMany = computed(() => gallery.value.length > 1);

// Volta ao fim quando passa da primeira, e ao comeco quando passa da ultima.
const step = delta => {
  if (!hasMany.value) return;
  const total = gallery.value.length;
  const next = (Math.max(currentIndex.value, 0) + delta + total) % total;
  resetZoomAndRotation();
  attachment.value = gallery.value[next];
};

const onKeydown = event => {
  if (!isOpen.value || !hasMany.value) return;
  if (event.key === 'ArrowLeft') {
    event.preventDefault();
    step(-1);
  } else if (event.key === 'ArrowRight') {
    event.preventDefault();
    step(1);
  }
};

onMounted(() => document.addEventListener('keydown', onKeydown));
onBeforeUnmount(() => document.removeEventListener('keydown', onKeydown));

const download = async () => {
  if (!attachment.value) return;
  try {
    await downloadFile({
      url: attachment.value.file_url,
      type: 'image',
      extension: attachment.value.filename?.split('.').pop(),
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ERROR'));
  }
};

defineExpose({ open, close, step });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="6xl"
    overflow-y-auto
    :title="attachment?.filename"
    :show-confirm-button="false"
    :cancel-button-label="t('TICKET.DETAIL.ATTACHMENTS.CLOSE_PREVIEW')"
    @close="onClosed"
  >
    <div v-if="attachment" class="flex flex-col items-center gap-3 min-w-0">
      <div class="flex items-center gap-1 flex-wrap justify-center">
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-zoom-out"
          :aria-label="t('TICKET.DETAIL.ATTACHMENTS.ZOOM_OUT')"
          @click="onZoom(-0.2)"
        />
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-zoom-in"
          :aria-label="t('TICKET.DETAIL.ATTACHMENTS.ZOOM_IN')"
          @click="onZoom(0.2)"
        />
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-rotate-ccw"
          :aria-label="t('TICKET.DETAIL.ATTACHMENTS.ROTATE_LEFT')"
          @click="onRotate('counter-clockwise')"
        />
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-rotate-cw"
          :aria-label="t('TICKET.DETAIL.ATTACHMENTS.ROTATE_RIGHT')"
          @click="onRotate('clockwise')"
        />
      </div>

      <div class="relative flex items-center justify-center w-full min-h-[40vh]">
        <Button
          v-if="hasMany"
          class="absolute z-10 -translate-y-1/2 start-0 top-1/2"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-chevron-left"
          :aria-label="t('TICKET.DETAIL.ATTACHMENTS.PREVIOUS_IMAGE')"
          data-testid="preview-previous"
          @click="step(-1)"
        />
        <Button
          v-if="hasMany"
          class="absolute z-10 -translate-y-1/2 end-0 top-1/2"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-chevron-right"
          :aria-label="t('TICKET.DETAIL.ATTACHMENTS.NEXT_IMAGE')"
          data-testid="preview-next"
          @click="step(1)"
        />
        <div
          :style="imageWrapperStyle"
          class="flex items-center justify-center origin-center"
        >
          <img
            ref="imageRef"
            :src="attachment.file_url"
            :alt="attachment.filename"
            :style="imageStyle"
            class="max-h-[70vh] max-w-full rounded-lg object-contain duration-100 ease-in-out transform select-none"
            @dblclick.stop="onDoubleClickZoomImage"
            @wheel.prevent.stop="onWheelImageZoom"
            draggable="false"
            @dragstart.prevent
            @pointerdown="onPanStart"
            @mousemove="onMouseMove"
            @mouseleave="onMouseLeave"
          />
        </div>
      </div>

      <p
        v-if="hasMany"
        class="m-0 text-xs text-n-slate-11"
        data-testid="preview-counter"
      >
        {{
          t('TICKET.DETAIL.ATTACHMENTS.IMAGE_COUNTER', {
            current: currentIndex + 1,
            total: gallery.length,
          })
        }}
      </p>

      <Button
        variant="faded"
        color="slate"
        size="sm"
        icon="i-lucide-download"
        :label="t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD')"
        @click="download"
      />
    </div>
  </Dialog>
</template>
