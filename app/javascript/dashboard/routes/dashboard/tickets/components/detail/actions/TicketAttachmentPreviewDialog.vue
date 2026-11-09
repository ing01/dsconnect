<script setup>
import { ref } from 'vue';
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

const open = selected => {
  resetZoomAndRotation();
  attachment.value = selected;
  dialogRef.value?.open();
};
const close = () => dialogRef.value?.close();

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

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    overflow-y-auto
    :title="attachment?.filename"
    :show-confirm-button="false"
    :cancel-button-label="t('TICKET.DETAIL.ATTACHMENTS.CLOSE_PREVIEW')"
    @close="resetZoomAndRotation"
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

      <div class="flex items-center justify-center w-full">
        <div
          :style="imageWrapperStyle"
          class="flex items-center justify-center origin-center"
        >
          <img
            ref="imageRef"
            :src="attachment.file_url"
            :alt="attachment.filename"
            :style="imageStyle"
            class="max-h-[50vh] max-w-[50vh] rounded-lg object-contain duration-100 ease-in-out transform select-none"
            @dblclick.stop="onDoubleClickZoomImage"
            @wheel.prevent.stop="onWheelImageZoom"
            @pointerdown="onPanStart"
            @mousemove="onMouseMove"
            @mouseleave="onMouseLeave"
          />
        </div>
      </div>

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
