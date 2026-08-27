<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';

const props = defineProps({
  modelValue: {
    type: Object,
    required: true,
  },
  allSteps: {
    type: Array,
    default: () => [],
  },
  currentStepId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const getters = useStoreGetters();
const teams = computed(() => getters['teams/getTeams'].value);
const queues = computed(() => getters['queues/getQueues'].value);

const step = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const options = computed({
  get: () => step.value.options || {},
  set: value => {
    step.value = { ...step.value, options: value };
  },
});

const otherSteps = computed(() =>
  props.allSteps.filter(candidate => candidate.id !== props.currentStepId)
);

const stepLabel = candidate => {
  const preview = (candidate.content || '').slice(0, 30);
  return `#${candidate.position + 1} ${t(`CONVERSATION_FLOWS_SETTINGS.STEPS.TYPES.${candidate.step_type.toUpperCase()}`)}${preview ? ` - ${preview}` : ''}`;
};

const updateStepType = value => {
  step.value = { ...step.value, step_type: value, options: {} };
};

const updateContent = value => {
  step.value = { ...step.value, content: value };
};

const updateNextStep = value => {
  step.value = { ...step.value, next_step_id: value || null };
};

const items = computed(() => (Array.isArray(step.value.options) ? step.value.options : []));

const setItems = value => {
  step.value = { ...step.value, options: value };
};

const addItem = () => {
  setItems([...items.value, { title: '', value: '', next_step_id: null }]);
};

const removeItem = index => {
  setItems(items.value.filter((_, i) => i !== index));
};

const updateItem = (index, key, value) => {
  const updated = items.value.map((item, i) => (i === index ? { ...item, [key]: value } : item));
  setItems(updated);
};

const showContent = computed(() =>
  ['send_message', 'ask_question', 'present_options'].includes(step.value.step_type)
);
const showNextStep = computed(() =>
  !['present_options', 'end_flow'].includes(step.value.step_type)
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.TYPE') }}
        <select :value="step.step_type" @change="updateStepType($event.target.value)">
          <option
            v-for="type in [
              'send_message', 'ask_question', 'present_options', 'transfer_team',
              'transfer_queue', 'add_label', 'set_priority', 'create_ticket', 'end_flow',
            ]"
            :key="type"
            :value="type"
          >
            {{ $t(`CONVERSATION_FLOWS_SETTINGS.STEPS.TYPES.${type.toUpperCase()}`) }}
          </option>
        </select>
      </label>
    </div>

    <div v-if="showContent" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.CONTENT') }}
        <textarea
          rows="2"
          :value="step.content"
          @input="updateContent($event.target.value)"
        />
      </label>
    </div>

    <div v-if="step.step_type === 'present_options'" class="flex flex-col gap-2">
      <label class="text-sm font-medium">
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.OPTIONS') }}
      </label>
      <div v-for="(item, index) in items" :key="index" class="flex gap-2 items-center">
        <input
          class="flex-1"
          :placeholder="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.OPTION_TITLE')"
          :value="item.title"
          @input="updateItem(index, 'title', $event.target.value)"
        />
        <input
          class="flex-1"
          :placeholder="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.OPTION_VALUE')"
          :value="item.value"
          @input="updateItem(index, 'value', $event.target.value)"
        />
        <select
          class="flex-1"
          :value="item.next_step_id"
          @change="updateItem(index, 'next_step_id', $event.target.value || null)"
        >
          <option :value="null">{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.NO_NEXT_STEP') }}</option>
          <option v-for="candidate in otherSteps" :key="candidate.id" :value="candidate.id">
            {{ stepLabel(candidate) }}
          </option>
        </select>
        <button type="button" class="text-n-ruby-11" @click="removeItem(index)">
          &times;
        </button>
      </div>
      <button type="button" class="text-n-blue-11 text-sm self-start" @click="addItem">
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.ADD_OPTION') }}
      </button>
    </div>

    <div v-if="step.step_type === 'transfer_team'" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.TEAM') }}
        <select
          :value="options.team_id"
          @change="options = { ...options, team_id: Number($event.target.value) }"
        >
          <option :value="null" disabled>{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.SELECT_TEAM') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">{{ team.name }}</option>
        </select>
      </label>
    </div>

    <div v-if="step.step_type === 'transfer_queue'" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.QUEUE') }}
        <select
          :value="options.queue_id"
          @change="options = { ...options, queue_id: Number($event.target.value) }"
        >
          <option :value="null" disabled>{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.SELECT_QUEUE') }}</option>
          <option v-for="queue in queues" :key="queue.id" :value="queue.id">{{ queue.name }}</option>
        </select>
      </label>
    </div>

    <div v-if="step.step_type === 'add_label'" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.LABELS') }}
        <input
          :value="(options.labels || []).join(', ')"
          :placeholder="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.LABELS_PLACEHOLDER')"
          @change="
            options = {
              ...options,
              labels: $event.target.value.split(',').map(l => l.trim()).filter(Boolean),
            }
          "
        />
      </label>
    </div>

    <div v-if="step.step_type === 'set_priority'" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.PRIORITY') }}
        <select
          :value="options.priority"
          @change="options = { ...options, priority: $event.target.value }"
        >
          <option value="low">{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.PRIORITY_LOW') }}</option>
          <option value="medium">{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.PRIORITY_MEDIUM') }}</option>
          <option value="high">{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.PRIORITY_HIGH') }}</option>
          <option value="urgent">{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.PRIORITY_URGENT') }}</option>
        </select>
      </label>
    </div>

    <div v-if="step.step_type === 'create_ticket'" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.TICKET_CATEGORY_ID') }}
        <input
          type="number"
          :value="options.ticket_category_id"
          :placeholder="$t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.TICKET_CATEGORY_ID_HINT')"
          @change="options = { ...options, ticket_category_id: Number($event.target.value) || null }"
        />
      </label>
    </div>

    <div v-if="showNextStep" class="w-full">
      <label>
        {{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.NEXT_STEP') }}
        <select :value="step.next_step_id" @change="updateNextStep($event.target.value)">
          <option :value="null">{{ $t('CONVERSATION_FLOWS_SETTINGS.STEPS.FIELDS.NO_NEXT_STEP') }}</option>
          <option v-for="candidate in otherSteps" :key="candidate.id" :value="candidate.id">
            {{ stepLabel(candidate) }}
          </option>
        </select>
      </label>
    </div>
  </div>
</template>
