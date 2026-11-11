<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import { useTrack } from 'dashboard/composables';

import { BUS_EVENTS } from 'shared/constants/busEvents';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  isLastMessage: {
    type: Boolean,
    default: false,
  },
  message: {
    type: Object,
    required: true,
  },
  conversationInboxType: {
    type: String,
    required: true,
  },
  // Id da mensagem no servidor e a avaliacao que esta pessoa ja deu a ela
  // ({ rating, reason, comment } ou null). Sem o id nao ha como avaliar.
  messageId: {
    type: Number,
    default: null,
  },
  feedback: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['rate', 'clearRate']);

const { t } = useI18n();

const hasEmptyMessageContent = computed(() => !props.message?.content);

const showUseButton = computed(() => {
  return (
    !hasEmptyMessageContent.value &&
    props.message.reply_suggestion &&
    props.isLastMessage
  );
});

const messageContent = computed(() => {
  const formatter = new MessageFormatter(props.message.content);
  return formatter.formattedMessage;
});

const insertIntoRichEditor = computed(() => {
  return [INBOX_TYPES.WEB, INBOX_TYPES.EMAIL].includes(
    props.conversationInboxType
  );
});

const useCopilotResponse = () => {
  if (insertIntoRichEditor.value) {
    emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, props.message?.content);
  } else {
    emitter.emit(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, props.message?.content);
  }
  useTrack(COPILOT_EVENTS.USE_CAPTAIN_RESPONSE);
};

// Feedback: o agente avalia a resposta e a avaliacao fica gravada para analise.
const canRate = computed(
  () => !hasEmptyMessageContent.value && props.messageId !== null
);
const isPositive = computed(() => props.feedback?.rating === 'positive');
const isNegative = computed(() => props.feedback?.rating === 'negative');

const showForm = ref(false);
const reason = ref('');
const comment = ref('');

// Chaves estaveis (iguais as do servidor); o texto vem da traducao.
const reasons = computed(() => [
  { value: 'wrong_answer', label: t('CAPTAIN.COPILOT.FEEDBACK.WRONG_ANSWER') },
  { value: 'incomplete', label: t('CAPTAIN.COPILOT.FEEDBACK.INCOMPLETE') },
  { value: 'not_helpful', label: t('CAPTAIN.COPILOT.FEEDBACK.NOT_HELPFUL') },
  { value: 'outdated', label: t('CAPTAIN.COPILOT.FEEDBACK.OUTDATED') },
  { value: 'other', label: t('CAPTAIN.COPILOT.FEEDBACK.OTHER') },
]);

// Polegar para cima grava na hora; clicar de novo no mesmo polegar desfaz.
const rateUp = () => {
  showForm.value = false;
  if (isPositive.value) {
    emit('clearRate', { messageId: props.messageId });
    return;
  }
  emit('rate', { messageId: props.messageId, rating: 'positive' });
};

// Polegar para baixo abre o motivo e o comentario antes de enviar. Se ja estava
// negativo, reabre com o que foi enviado (para editar).
const rateDown = () => {
  if (showForm.value) {
    showForm.value = false;
    return;
  }
  reason.value = isNegative.value ? props.feedback?.reason || '' : '';
  comment.value = isNegative.value ? props.feedback?.comment || '' : '';
  showForm.value = true;
};

const sendNegative = () => {
  emit('rate', {
    messageId: props.messageId,
    rating: 'negative',
    reason: reason.value || undefined,
    comment: comment.value.trim() || undefined,
  });
  showForm.value = false;
};

const removeNegative = () => {
  showForm.value = false;
  emit('clearRate', { messageId: props.messageId });
};
</script>

<template>
  <div class="flex flex-col gap-1 text-n-slate-12">
    <div class="font-medium">{{ $t('CAPTAIN.NAME') }}</div>
    <span v-if="hasEmptyMessageContent" class="text-n-ruby-11">
      {{ $t('CAPTAIN.COPILOT.EMPTY_MESSAGE') }}
    </span>
    <div
      v-else
      v-dompurify-html="messageContent"
      class="prose-sm break-words"
    />
    <div class="flex flex-row items-center gap-1 mt-1">
      <Button
        v-if="showUseButton"
        :label="$t('CAPTAIN.COPILOT.USE')"
        faded
        sm
        slate
        @click="useCopilotResponse"
      />
      <template v-if="canRate">
        <Button
          data-testid="feedback-up"
          variant="ghost"
          :color="isPositive ? 'teal' : 'slate'"
          size="xs"
          icon="i-lucide-thumbs-up"
          :title="t('CAPTAIN.COPILOT.FEEDBACK.USEFUL')"
          :aria-label="t('CAPTAIN.COPILOT.FEEDBACK.USEFUL')"
          :aria-pressed="isPositive"
          @click="rateUp"
        />
        <Button
          data-testid="feedback-down"
          variant="ghost"
          :color="isNegative ? 'ruby' : 'slate'"
          size="xs"
          icon="i-lucide-thumbs-down"
          :title="t('CAPTAIN.COPILOT.FEEDBACK.NOT_USEFUL')"
          :aria-label="t('CAPTAIN.COPILOT.FEEDBACK.NOT_USEFUL')"
          :aria-pressed="isNegative"
          @click="rateDown"
        />
        <span
          v-if="feedback && !showForm"
          data-testid="feedback-thanks"
          class="text-xs text-n-slate-11"
        >
          {{ t('CAPTAIN.COPILOT.FEEDBACK.THANKS') }}
        </span>
      </template>
    </div>

    <div
      v-if="canRate && showForm"
      data-testid="feedback-form"
      class="flex flex-col gap-2 p-3 mt-1 border rounded-lg border-n-weak bg-n-solid-2"
    >
      <span class="text-sm font-medium">
        {{ t('CAPTAIN.COPILOT.FEEDBACK.QUESTION') }}
      </span>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="option in reasons"
          :key="option.value"
          type="button"
          class="px-2 py-1 text-xs border rounded-full"
          :class="
            reason === option.value
              ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
              : 'border-n-weak text-n-slate-11 hover:border-n-slate-7'
          "
          :aria-pressed="reason === option.value"
          @click="reason = reason === option.value ? '' : option.value"
        >
          {{ option.label }}
        </button>
      </div>
      <textarea
        v-model="comment"
        data-testid="feedback-comment"
        rows="2"
        maxlength="2000"
        class="w-full p-2 text-sm border rounded-lg resize-none border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10"
        :placeholder="t('CAPTAIN.COPILOT.FEEDBACK.COMMENT_PLACEHOLDER')"
      />
      <div class="flex items-center gap-2">
        <Button
          data-testid="feedback-send"
          :label="t('CAPTAIN.COPILOT.FEEDBACK.SEND')"
          size="xs"
          @click="sendNegative"
        />
        <Button
          :label="t('CAPTAIN.COPILOT.FEEDBACK.CANCEL')"
          variant="ghost"
          color="slate"
          size="xs"
          @click="showForm = false"
        />
        <Button
          v-if="isNegative"
          :label="t('CAPTAIN.COPILOT.FEEDBACK.REMOVE')"
          variant="ghost"
          color="slate"
          size="xs"
          class="ltr:ml-auto rtl:mr-auto"
          @click="removeNegative"
        />
      </div>
    </div>
  </div>
</template>
