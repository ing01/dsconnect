<script setup>
import { ref, watch } from 'vue';
import Draggable from 'vuedraggable';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import FlowStep from './FlowStep.vue';

const props = defineProps({
  flowId: {
    type: Number,
    required: true,
  },
  steps: {
    type: Array,
    default: () => [],
  },
});

const store = useStore();
const { t } = useI18n();

const localSteps = ref([...props.steps]);
watch(
  () => props.steps,
  newSteps => {
    localSteps.value = [...newSteps];
  }
);

const addStep = async () => {
  try {
    await store.dispatch('flowSteps/create', {
      flowId: props.flowId,
      step_type: 'send_message',
      content: t('CONVERSATION_FLOWS_SETTINGS.STEPS.DEFAULT_CONTENT'),
      options: {},
    });
  } catch (error) {
    useAlert(error.message || t('CONVERSATION_FLOWS_SETTINGS.STEPS.API.ERROR_MESSAGE'));
  }
};

const onDragEnd = async () => {
  try {
    await store.dispatch('flowSteps/reorder', {
      flowId: props.flowId,
      stepIds: localSteps.value.map(step => step.id),
    });
  } catch (error) {
    useAlert(t('CONVERSATION_FLOWS_SETTINGS.STEPS.API.REORDER_ERROR'));
  }
};
</script>

<template>
  <div class="flow-steps">
    <div class="flow-step-pill">
      <span class="bg-n-solid-blue text-n-blue-11 py-1 px-1.5 leading-none text-sm rounded-md">
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.START') }}
      </span>
    </div>
    <Draggable
      :list="localSteps"
      animation="200"
      item-key="id"
      ghost-class="ghost"
      tag="div"
      handle=".flow-step-drag-handle"
      @end="onDragEnd"
    >
      <template #item="{ element: step }">
        <div :key="step.id" class="flow-step-pill">
          <FlowStep
            :flow-id="flowId"
            :step="step"
            :all-steps="steps"
          />
        </div>
      </template>
    </Draggable>
    <div class="flow-step-pill">
      <Button
        icon="i-lucide-plus-circle"
        solid
        teal
        :label="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.ADD_BTN')"
        @click="addStep"
      />
    </div>
    <div class="flow-step-pill">
      <span class="bg-n-solid-blue text-n-blue-11 py-1 px-1.5 leading-none text-sm rounded-md">
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.END') }}
      </span>
    </div>
  </div>
</template>

<style scoped lang="scss">
.flow-steps {
  max-width: 720px;
}

.flow-step-pill:not(:last-child) {
  padding-bottom: 1.5rem;
}
</style>
