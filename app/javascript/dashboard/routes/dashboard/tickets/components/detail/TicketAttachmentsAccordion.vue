<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { formatBytes } from 'shared/helpers/FileHelper';
import { downloadFile } from '@chatwoot/utils';
import { downloadBlob } from 'dashboard/helper/downloadHelper';
import TicketsAPI from 'dashboard/api/tickets';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketAttachmentPreviewDialog from './actions/TicketAttachmentPreviewDialog.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
  canUpdate: { type: Boolean, default: true },
});

const { t } = useI18n();
const store = useStore();

const fileInput = ref(null);
const hasLoaded = ref(false);
const isDownloadingAll = ref(false);
const previewDialog = ref(null);

const uiFlags = useMapGetter('tickets/getUIFlags');
const attachments = computed(
  () => store.getters['tickets/getAttachments'](props.ticketId) || []
);

const isImage = attachment =>
  (attachment.content_type || '').startsWith('image/');

// Imagem abre em pre-visualizacao; qualquer outro tipo segue o padrao do
// navegador (abre numa aba nova, que baixa ou mostra conforme o tipo) - so'
// imagem tem o que uma pre-visualizacao acrescente aqui.
const openAttachment = attachment => {
  if (!isImage(attachment)) {
    window.open(attachment.file_url, '_blank', 'noopener,noreferrer');
    return;
  }
  previewDialog.value?.open(attachment);
};

const download = async attachment => {
  try {
    await downloadFile({
      url: attachment.file_url,
      type: isImage(attachment) ? 'image' : 'file',
      extension: attachment.filename?.split('.').pop(),
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ERROR'));
  }
};

const downloadAll = async () => {
  isDownloadingAll.value = true;
  try {
    const response = await TicketsAPI.downloadAllAttachments(props.ticketId);
    downloadBlob(
      response.data,
      `ticket-${props.ticketId}-anexos.zip`,
      response.headers?.['content-disposition']
    );
  } catch (error) {
    useAlert(t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL_ERROR'));
  } finally {
    isDownloadingAll.value = false;
  }
};

const load = async () => {
  if (hasLoaded.value) return;
  hasLoaded.value = true;
  try {
    await store.dispatch('tickets/fetchAttachments', props.ticketId);
  } catch (error) {
    hasLoaded.value = false;
  }
};

// Busca a contagem real assim que o ticket carrega, mesmo com o acordeao
// fechado - sem isso o titulo mostra "Arquivo (0)" ate alguem clicar pra
// expandir (ver `load`, so disparado antes no @toggle do Accordion).
onMounted(load);

const pickFile = () => fileInput.value?.click();

const onFileSelected = async event => {
  const [file] = event.target.files || [];
  event.target.value = '';
  if (!file) return;

  try {
    await store.dispatch('tickets/createAttachment', {
      ticketId: props.ticketId,
      file,
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.ATTACHMENTS.UPLOAD_ERROR'));
  }
};

const remove = async attachmentId => {
  try {
    await store.dispatch('tickets/deleteAttachment', {
      ticketId: props.ticketId,
      attachmentId,
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.ATTACHMENTS.DELETE_ERROR'));
  }
};

const title = computed(
  () => `${t('TICKET.DETAIL.ATTACHMENTS.TITLE')} (${attachments.value.length})`
);
</script>

<template>
  <Accordion :title="title" @toggle="expanded => expanded && load()">
    <div class="flex flex-col gap-3 pt-2">
      <div
        v-if="uiFlags.isFetchingAttachments"
        class="flex justify-center py-3"
      >
        <Spinner :size="20" />
      </div>

      <p v-else-if="!attachments.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.ATTACHMENTS.EMPTY') }}
      </p>

      <ul v-else class="flex flex-col gap-1">
        <li
          v-for="attachment in attachments"
          :key="attachment.id"
          class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-n-alpha-2 group min-w-0"
        >
          <Icon
            icon="i-lucide-paperclip"
            class="size-4 text-n-slate-11 flex-shrink-0"
          />
          <button
            type="button"
            class="flex-1 min-w-0 text-sm text-left text-n-slate-12 hover:text-n-blue-11 truncate"
            :title="attachment.filename"
            @click="openAttachment(attachment)"
          >
            {{ attachment.filename }}
          </button>
          <span class="text-xs text-n-slate-10 flex-shrink-0">
            {{ formatBytes(attachment.byte_size) }}
          </span>
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-download"
            class="opacity-0 group-hover:opacity-100 focus-visible:opacity-100"
            :aria-label="t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD')"
            @click="download(attachment)"
          />
          <Button
            v-if="canUpdate"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-trash-2"
            class="opacity-0 group-hover:opacity-100 focus-visible:opacity-100"
            :aria-label="t('TICKET.DETAIL.ATTACHMENTS.DELETE')"
            @click="remove(attachment.id)"
          />
        </li>
      </ul>

      <div class="flex flex-wrap gap-2">
        <div v-if="canUpdate">
          <input
            ref="fileInput"
            type="file"
            class="hidden"
            @change="onFileSelected"
          />
          <Button
            variant="faded"
            color="slate"
            size="sm"
            icon="i-lucide-upload"
            :is-loading="uiFlags.isUploadingAttachment"
            :label="t('TICKET.DETAIL.ATTACHMENTS.ADD')"
            @click="pickFile"
          />
        </div>
        <Button
          v-if="attachments.length > 1"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-archive"
          :is-loading="isDownloadingAll"
          :label="
            isDownloadingAll
              ? t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL_WORKING')
              : t('TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL')
          "
          @click="downloadAll"
        />
      </div>
    </div>
  </Accordion>
  <TicketAttachmentPreviewDialog ref="previewDialog" />
</template>
