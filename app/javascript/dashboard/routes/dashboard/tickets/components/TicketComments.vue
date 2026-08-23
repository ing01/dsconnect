<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  ticketId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const currentUserId = useMapGetter('getCurrentUserID');

const newComment = ref('');

const comments = computed(() =>
  store.getters['tickets/getComments'](props.ticketId)
);
const uiFlags = computed(() => store.getters['tickets/getUIFlags']);
const isLoading = computed(() => uiFlags.value.isFetchingComments);
const isSubmitting = computed(() => uiFlags.value.isCreatingComment);

const submitComment = async () => {
  if (!newComment.value.trim()) return;
  try {
    await store.dispatch('tickets/createComment', {
      ticketId: props.ticketId,
      content: newComment.value.trim(),
    });
    newComment.value = '';
  } catch (error) {
    useAlert(t('TICKET.COMMENTS.ERROR'));
  }
};

const removeComment = async commentId => {
  try {
    await store.dispatch('tickets/deleteComment', {
      ticketId: props.ticketId,
      commentId,
    });
  } catch (error) {
    useAlert(t('TICKET.COMMENTS.ERROR'));
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
      </li>
    </ul>

    <div class="flex flex-col gap-2">
      <textarea
        v-model="newComment"
        rows="2"
        class="w-full rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
        :placeholder="t('TICKET.COMMENTS.PLACEHOLDER')"
      />
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
