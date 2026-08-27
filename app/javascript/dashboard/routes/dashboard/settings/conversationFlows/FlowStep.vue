<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import FlowStepInput from './FlowStepInput.vue';

const props = defineProps({
  flowId: {
    type: Number,
    required: true,
  },
  step: {
    type: Object,
    required: true,
  },
  allSteps: {
    type: Array,
    default: () => [],
  },
});

const store = useStore();
const { t } = useI18n();

const localStep = ref({ ...props.step });
const isSaving = ref(false);
const isDeleting = ref(false);

watch(
  () => props.step,
  newStep => {
    localStep.value = { ...newStep };
  }
);

const save = async () => {
  isSaving.value = true;
  try {
    await store.dispatch('flowSteps/update', {
      flowId: props.flowId,
      stepId: props.step.id,
      step_type: localStep.value.step_type,
      content: localStep.value.content,
      options: localStep.value.options,
      next_step_id: localStep.value.next_step_id,
    });
    useAlert(t('CONVERSATION_FLOWS_SETTINGS.STEPS.API.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('CONVERSATION_FLOWS_SETTINGS.STEPS.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};

const remove = async () => {
  isDeleting.value = true;
  try {
    await store.dispatch('flowSteps/delete', {
      flowId: props.flowId,
      stepId: props.step.id,
    });
  } catch (error) {
    useAlert(error.message || t('CONVERSATION_FLOWS_SETTINGS.STEPS.API.ERROR_MESSAGE'));
  } finally {
    isDeleting.value = false;
  }
};
</script>

<template>
  <div class="relative flex items-start w-full min-w-0 basis-full">
    <Button
      ghost
      sm
      slate
      icon="i-lucide-menu"
      class="absolute cursor-move ltr:-left-10 rtl:-right-10 flow-step-drag-handle"
    />
    <div
      class="flex-grow p-3 ltr:mr-2 rtl:ml-2 rounded-md shadow-sm outline outline-1 outline-n-weak bg-n-background dark:bg-n-solid-1"
    >
      <FlowStepInput v-model="localStep" :all-steps="allSteps" :current-step-id="step.id" />
      <div class="flex justify-end pt-2">
        <Button size="sm" :label="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.SAVE')" :is-loading="isSaving" @click="save" />
      </div>
    </div>
    <Button
      v-tooltip="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.DELETE')"
      icon="i-lucide-trash-2"
      sm
      faded
      ruby
      class="flex-shrink-0"
      :is-loading="isDeleting"
      @click="remove"
    />
  </div>
</template>
