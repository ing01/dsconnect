<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import TicketsAPI from 'dashboard/api/tickets';
import { TICKET_DESCRIPTION_TEMPLATE } from '../../helpers/descriptionTemplate';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

// The article editor's own option set minus `imageUpload` and `video`:
// FullEditor's image button dispatches `articles/attachImage` with
// `$route.params.portalSlug`, which does not exist on the ticket route.
const DESCRIPTION_MENU_OPTIONS = [
  'bold',
  'italic',
  'strike',
  'link',
  'undo',
  'redo',
  'code',
  'h1',
  'h2',
  'h3',
  'bulletList',
  'orderedList',
  'blockquote',
  'codeBlock',
];

const { t } = useI18n();

const isEditing = ref(false);
const draft = ref('');
const isSummarizing = ref(false);

const hasDescription = computed(() =>
  Boolean(props.ticket.description?.trim())
);

// So' oferece o resumo por IA quando ha' pelo menos uma Conversation
// vinculada ao Ticket (ver TicketConversation) - sem isso o backend so'
// devolveria um erro de "nada para resumir".
const hasLinkedConversation = computed(
  () => (props.ticket.conversations || []).length > 0
);

const renderedDescription = computed(
  () => new MessageFormatter(props.ticket.description || '').formattedMessage
);

const startEditing = (seed = null) => {
  draft.value = seed ?? props.ticket.description ?? '';
  isEditing.value = true;
};

const cancel = () => {
  isEditing.value = false;
  draft.value = '';
};

const save = () => {
  emit('save', draft.value);
};

const summarizeConversation = async () => {
  isSummarizing.value = true;
  try {
    const { data } = await TicketsAPI.summarizeConversation(props.ticket.id);
    if (!data.message) {
      useAlert(t('TICKET.DETAIL.DESCRIPTION.SUMMARIZE_EMPTY'));
      return;
    }
    startEditing(data.message);
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('TICKET.DETAIL.DESCRIPTION.SUMMARIZE_ERROR')
    );
  } finally {
    isSummarizing.value = false;
  }
};

// Leaving edit mode is driven by the parent: it flips `isSaving` back once the
// request settles, and the fresh description arrives through the ticket prop.
watch(
  () => props.ticket.description,
  () => {
    if (isEditing.value && !props.isSaving) cancel();
  }
);
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <div class="flex items-center justify-between gap-2">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.DESCRIPTION.TITLE') }}
      </h2>
      <div v-if="!isEditing && canUpdate" class="flex items-center gap-2">
        <Button
          v-if="hasLinkedConversation"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-fluent-text-bullet-list-square-sparkle-32-regular"
          :is-loading="isSummarizing"
          :label="t('TICKET.DETAIL.DESCRIPTION.SUMMARIZE')"
          @click="summarizeConversation"
        />
        <Button
          v-if="!hasDescription"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-list-checks"
          :label="t('TICKET.DETAIL.DESCRIPTION.USE_TEMPLATE')"
          @click="startEditing(TICKET_DESCRIPTION_TEMPLATE)"
        />
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-pencil"
          :label="t('TICKET.DETAIL.DESCRIPTION.EDIT')"
          @click="startEditing()"
        />
      </div>
    </div>

    <template v-if="isEditing">
      <FullEditor
        v-model="draft"
        :editor-id="`ticket-description-${ticket.id}`"
        :placeholder="t('TICKET.DETAIL.DESCRIPTION.PLACEHOLDER')"
        :enabled-menu-options="DESCRIPTION_MENU_OPTIONS"
        class="min-w-0"
      />
      <div class="flex justify-end gap-2">
        <Button
          v-if="hasLinkedConversation"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-fluent-text-bullet-list-square-sparkle-32-regular"
          :is-loading="isSummarizing"
          :label="t('TICKET.DETAIL.DESCRIPTION.SUMMARIZE')"
          class="mr-auto"
          @click="summarizeConversation"
        />
        <Button
          variant="faded"
          color="slate"
          size="sm"
          :label="t('TICKET.DETAIL.DESCRIPTION.CANCEL')"
          @click="cancel"
        />
        <Button
          size="sm"
          :is-loading="isSaving"
          :label="t('TICKET.DETAIL.DESCRIPTION.SAVE')"
          @click="save"
        />
      </div>
    </template>

    <div
      v-else-if="hasDescription"
      v-dompurify-html="renderedDescription"
      class="prose-sm max-w-none text-sm text-n-slate-12 break-words"
    />

    <p v-else class="text-sm text-n-slate-10">
      {{ t('TICKET.DETAIL.NO_DESCRIPTION') }}
    </p>
  </section>
</template>
