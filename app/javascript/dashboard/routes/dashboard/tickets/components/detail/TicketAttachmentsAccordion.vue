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
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
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

// Um por vez, em ordem: a acao de upload/exclusao controla a bandeira de "em
// andamento" por item, entao em paralelo ela voltaria a "livre" no primeiro que
// terminasse.
const inSequence = (items, task) =>
  items.reduce(
    (chain, item) => chain.then(() => task(item)),
    Promise.resolve()
  );

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

// Aceita varios arquivos de uma vez, vindos do seletor ou de arrastar e soltar.
// Sobem um a um (a acao de upload controla a bandeira de "enviando" por arquivo),
// e um que falhe nao impede os outros: no fim, o aviso diz quais nao subiram.
const uploadFiles = async files => {
  if (!files.length) return;

  const failed = [];
  await inSequence(files, async file => {
    try {
      await store.dispatch('tickets/createAttachment', {
        ticketId: props.ticketId,
        file,
      });
    } catch (error) {
      failed.push(file.name);
    }
  });

  if (failed.length) {
    useAlert(
      `${t('TICKET.DETAIL.ATTACHMENTS.UPLOAD_ERROR')} ${failed.join(', ')}`
    );
  }
};

const onFileSelected = event => {
  const files = Array.from(event.target.files || []);
  // Limpo para escolher o mesmo arquivo de novo ainda disparar `change`.
  event.target.value = '';
  return uploadFiles(files);
};

// Arrastar e soltar. O contador de `dragenter`/`dragleave` existe porque esses
// eventos disparam tambem ao passar por cada elemento filho: sem ele o destaque
// piscava ao arrastar sobre a lista.
const isDragging = ref(false);
let dragDepth = 0;

const hasFiles = event =>
  Array.from(event.dataTransfer?.types || []).includes('Files');

// Pasta solta junto vem como um "arquivo" vazio: so entram arquivos de verdade.
// Lido na hora do `drop` - depois dele o navegador esvazia a lista.
const droppedFiles = event => {
  const { items, files } = event.dataTransfer;
  if (!items?.length) return Array.from(files || []);
  return Array.from(items)
    .filter(item => item.kind === 'file')
    .filter(item => item.webkitGetAsEntry?.()?.isFile ?? true)
    .map(item => item.getAsFile())
    .filter(Boolean);
};

const onDragEnter = event => {
  if (!props.canUpdate || !hasFiles(event)) return;
  dragDepth += 1;
  isDragging.value = true;
};

const onDragLeave = () => {
  if (!isDragging.value) return;
  dragDepth = Math.max(0, dragDepth - 1);
  if (dragDepth === 0) isDragging.value = false;
};

const onDragOver = event => {
  if (!props.canUpdate || !hasFiles(event)) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = 'copy';
};

const onDrop = event => {
  dragDepth = 0;
  isDragging.value = false;
  if (!props.canUpdate || !hasFiles(event)) return;
  event.preventDefault();
  uploadFiles(droppedFiles(event));
};

// Selecao para excluir varios de uma vez. So guarda ids; o que ja nao existe mais
// na lista (excluido, ou ticket trocado) sai da selecao sozinho.
const selectedIds = ref([]);
const isDeletingSelected = ref(false);

const selected = computed(() =>
  selectedIds.value.filter(id =>
    attachments.value.some(attachment => attachment.id === id)
  )
);
const allSelected = computed(
  () =>
    attachments.value.length > 0 &&
    selected.value.length === attachments.value.length
);

const toggleOne = (id, checked) => {
  selectedIds.value = checked
    ? [...selected.value, id]
    : selected.value.filter(item => item !== id);
};

const toggleAll = checked => {
  selectedIds.value = checked
    ? attachments.value.map(attachment => attachment.id)
    : [];
};

const removeSelected = async () => {
  const ids = [...selected.value];
  if (!ids.length || isDeletingSelected.value) return;

  const question = t(
    'TICKET.DETAIL.ATTACHMENTS.DELETE_SELECTED_CONFIRM',
    { count: ids.length },
    ids.length
  );
  // eslint-disable-next-line no-alert
  if (!window.confirm(question)) return;

  const names = Object.fromEntries(
    attachments.value.map(attachment => [attachment.id, attachment.filename])
  );
  const failed = [];
  isDeletingSelected.value = true;
  await inSequence(ids, async attachmentId => {
    try {
      await store.dispatch('tickets/deleteAttachment', {
        ticketId: props.ticketId,
        attachmentId,
      });
    } catch (error) {
      failed.push(attachmentId);
    }
  });
  isDeletingSelected.value = false;

  // O que nao saiu continua selecionado, para tentar de novo.
  selectedIds.value = failed;
  if (failed.length) {
    useAlert(
      `${t('TICKET.DETAIL.ATTACHMENTS.DELETE_ERROR')} ${failed
        .map(id => names[id])
        .join(', ')}`
    );
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
    <div
      class="flex flex-col gap-3 pt-2 rounded-lg"
      :class="isDragging ? 'ring-2 ring-n-brand bg-n-alpha-1' : ''"
      @dragenter="onDragEnter"
      @dragleave="onDragLeave"
      @dragover="onDragOver"
      @drop="onDrop"
    >
      <p
        v-if="isDragging"
        class="py-3 text-sm font-medium text-center text-n-blue-11 drop-hint"
      >
        {{ t('TICKET.DETAIL.ATTACHMENTS.DROP_HERE') }}
      </p>

      <div
        v-if="uiFlags.isFetchingAttachments"
        class="flex justify-center py-3"
      >
        <Spinner :size="20" />
      </div>

      <p v-else-if="!attachments.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.ATTACHMENTS.EMPTY') }}
      </p>

      <template v-else>
        <!-- Selecionar varios para excluir de uma vez. So' para quem pode editar. -->
        <div
          v-if="canUpdate"
          class="flex items-center justify-between gap-2 px-2 min-w-0"
        >
          <label
            class="flex items-center gap-2 text-xs cursor-pointer text-n-slate-11 select-all-attachments"
          >
            <Checkbox
              :model-value="allSelected"
              @update:model-value="toggleAll"
            />
            {{ t('TICKET.DETAIL.ATTACHMENTS.SELECT_ALL') }}
          </label>
          <Button
            v-if="selected.length"
            variant="faded"
            color="ruby"
            size="xs"
            icon="i-lucide-trash-2"
            class="delete-selected"
            :is-loading="isDeletingSelected"
            :label="
              t(
                'TICKET.DETAIL.ATTACHMENTS.DELETE_SELECTED',
                { count: selected.length },
                selected.length
              )
            "
            @click="removeSelected"
          />
        </div>

        <ul class="flex flex-col gap-1">
          <li
            v-for="attachment in attachments"
            :key="attachment.id"
            class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-n-alpha-2 group min-w-0"
          >
            <Checkbox
              v-if="canUpdate"
              class="flex-shrink-0 attachment-checkbox"
              :model-value="selected.includes(attachment.id)"
              @update:model-value="checked => toggleOne(attachment.id, checked)"
            />
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
      </template>

      <div class="flex flex-wrap items-center gap-2">
        <div v-if="canUpdate">
          <input
            ref="fileInput"
            type="file"
            multiple
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
        <span v-if="canUpdate" class="text-xs text-n-slate-10">
          {{ t('TICKET.DETAIL.ATTACHMENTS.DROP_HINT') }}
        </span>
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
