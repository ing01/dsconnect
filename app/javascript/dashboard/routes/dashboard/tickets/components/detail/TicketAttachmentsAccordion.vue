<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { formatBytes } from 'shared/helpers/FileHelper';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
  canUpdate: { type: Boolean, default: true },
});

const { t } = useI18n();
const store = useStore();

const fileInput = ref(null);
const hasLoaded = ref(false);

const uiFlags = useMapGetter('tickets/getUIFlags');
const attachments = computed(
  () => store.getters['tickets/getAttachments'](props.ticketId) || []
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
          <a
            :href="attachment.file_url"
            target="_blank"
            rel="noopener noreferrer"
            class="flex-1 min-w-0 text-sm text-n-slate-12 hover:text-n-blue-11 truncate"
            :title="attachment.filename"
          >
            {{ attachment.filename }}
          </a>
          <span class="text-xs text-n-slate-10 flex-shrink-0">
            {{ formatBytes(attachment.byte_size) }}
          </span>
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
    </div>
  </Accordion>
</template>
