<script setup>
import { reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/inbox/conversation';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
});
const emit = defineEmits(['close']);

const { t } = useI18n();
const isSaving = ref(false);
const form = reactive({
  hours: 1,
  minutes: 0,
  reason: '',
  notifyCustomer: true,
});

const inputClass =
  'w-full px-3 py-2 text-sm rounded-lg outline outline-1 -outline-offset-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12 focus:outline-n-brand';

const submit = async () => {
  if (!form.reason.trim()) {
    useAlert(t('CONVERSATION.EXTEND_PAUSE.ERRORS.reason_required'));
    return;
  }
  isSaving.value = true;
  try {
    await ConversationApi.extendPause({
      conversationId: props.conversationId,
      hours: Number(form.hours) || 0,
      minutes: Number(form.minutes) || 0,
      reason: form.reason,
      notifyCustomer: form.notifyCustomer,
    });
    useAlert(t('CONVERSATION.EXTEND_PAUSE.SUCCESS'));
    emit('close');
  } catch (error) {
    const code = error?.response?.data?.error;
    useAlert(
      t(`CONVERSATION.EXTEND_PAUSE.ERRORS.${code}`, t('CONVERSATION.EXTEND_PAUSE.ERRORS.generic'))
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    @click.self="emit('close')"
  >
    <div
      class="flex flex-col w-full max-w-md gap-4 p-6 mx-4 rounded-xl shadow-lg bg-n-solid-2"
    >
      <h3 class="text-base font-medium text-n-slate-12">
        {{ t('CONVERSATION.EXTEND_PAUSE.TITLE') }}
      </h3>

      <div class="flex gap-3">
        <label class="flex flex-col flex-1 gap-1 text-sm text-n-slate-11">
          {{ t('CONVERSATION.EXTEND_PAUSE.HOURS') }}
          <input v-model="form.hours" type="number" min="0" :class="inputClass" />
        </label>
        <label class="flex flex-col flex-1 gap-1 text-sm text-n-slate-11">
          {{ t('CONVERSATION.EXTEND_PAUSE.MINUTES') }}
          <input
            v-model="form.minutes"
            type="number"
            min="0"
            max="59"
            :class="inputClass"
          />
        </label>
      </div>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('CONVERSATION.EXTEND_PAUSE.REASON') }}
        <textarea
          v-model="form.reason"
          rows="3"
          :class="inputClass"
          :placeholder="t('CONVERSATION.EXTEND_PAUSE.REASON_PLACEHOLDER')"
        />
        <span class="text-xs">{{ t('CONVERSATION.EXTEND_PAUSE.REASON_HELP') }}</span>
      </label>

      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="form.notifyCustomer" type="checkbox" class="!m-0" />
        {{ t('CONVERSATION.EXTEND_PAUSE.NOTIFY_CUSTOMER') }}
      </label>

      <div class="flex justify-end gap-2">
        <NextButton
          slate
          faded
          :label="t('CONVERSATION.EXTEND_PAUSE.CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          :is-loading="isSaving"
          :label="t('CONVERSATION.EXTEND_PAUSE.CONFIRM')"
          @click="submit"
        />
      </div>
    </div>
  </div>
</template>
