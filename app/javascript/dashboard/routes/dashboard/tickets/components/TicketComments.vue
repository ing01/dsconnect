<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useTextDraft } from 'dashboard/composables/useTextDraft';
import DraftNotice from 'dashboard/components-next/draft/DraftNotice.vue';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketFileInput from 'dashboard/routes/dashboard/tickets/components/create/TicketFileInput.vue';

const props = defineProps({
  ticketId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const currentUserId = useMapGetter('getCurrentUserID');

const draft = useTextDraft('ticket-comment', () => props.ticketId);
const { text: newComment, isRestored } = draft;
const newAttachments = ref([]);

// Anexo escolhido para um ticket nao pode seguir para outro.
watch(
  () => props.ticketId,
  () => {
    newAttachments.value = [];
  }
);

const comments = computed(() =>
  store.getters['tickets/getComments'](props.ticketId)
);
const uiFlags = computed(() => store.getters['tickets/getUIFlags']);
const isLoading = computed(() => uiFlags.value.isFetchingComments);
const isSubmitting = computed(() => uiFlags.value.isCreatingComment);

const submitComment = async () => {
  if (!newComment.value.trim()) return;
  const sent = draft.snapshot();
  const { ticketId } = props;
  try {
    await store.dispatch('tickets/createComment', {
      ticketId,
      content: sent.text.trim(),
      attachments: newAttachments.value,
    });
    draft.clear(sent);
    if (ticketId === props.ticketId) newAttachments.value = [];
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.COMMENTS.ERROR'));
  }
};

const removeComment = async commentId => {
  try {
    await store.dispatch('tickets/deleteComment', {
      ticketId: props.ticketId,
      commentId,
    });
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.COMMENTS.ERROR'));
  }
};

const formattedTime = comment =>
  new Date(comment.created_at * 1000).toLocaleString();

onMounted(() => store.dispatch('tickets/fetchComments', props.ticketId));
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-xs text-n-slate-10">
      {{ t('TICKET.COMMENTS.INTERNAL_NOTICE') }}
    </p>

    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner />
    </div>
    <p v-else-if="!comments.length" class="text-sm text-n-slate-11">
      {{ t('TICKET.COMMENTS.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-3">
      <li
        v-for="comment in comments"
        :key="comment.id"
        class="group flex flex-col gap-1 rounded-lg bg-n-slate-2 p-2.5"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs font-medium text-n-slate-12">{{
            comment.user.name
          }}</span>
          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-10">{{
              formattedTime(comment)
            }}</span>
            <button
              v-if="comment.user.id === currentUserId"
              type="button"
              class="hidden group-hover:inline text-xs text-n-ruby-9"
              @click="removeComment(comment.id)"
            >
              {{ t('TICKET.COMMENTS.DELETE') }}
            </button>
          </div>
        </div>
        <p class="text-sm text-n-slate-12 whitespace-pre-wrap">
          {{ comment.content }}
        </p>
        <ul v-if="comment.attachments?.length" class="flex flex-wrap gap-2 m-0">
          <li v-for="anexo in comment.attachments" :key="anexo.id">
            <a
              :href="anexo.file_url"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-1.5 px-2 py-1 text-xs border rounded-md border-n-weak text-n-slate-11 hover:text-n-brand"
            >
              <Icon icon="i-lucide-paperclip" class="size-3" />
              {{ anexo.filename }}
            </a>
          </li>
        </ul>
      </li>
    </ul>

    <div class="flex flex-col gap-2">
      <DraftNotice v-if="isRestored" @discard="draft.discard" />
      <textarea
        v-model="newComment"
        rows="2"
        class="w-full rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
        :placeholder="t('TICKET.COMMENTS.PLACEHOLDER')"
      />
      <TicketFileInput v-model="newAttachments" />
      <div class="flex justify-end">
        <NextButton
          size="sm"
          :is-loading="isSubmitting"
          :disabled="!newComment.trim()"
          :label="t('TICKET.COMMENTS.SUBMIT')"
          @click="submitComment"
        />
      </div>
    </div>
  </div>
</template>
