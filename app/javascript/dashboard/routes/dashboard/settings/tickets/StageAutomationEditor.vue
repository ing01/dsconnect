<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
});
const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

// Mesma lista de TicketColumn::AUTOMATION_ACTION_TYPES no backend - a
// validacao de verdade mora la, esta so decide o que a tela oferece.
const ACTION_TYPES = [
  'set_priority',
  'set_status',
  'set_assignee',
  'clear_due_date',
  'clear_scheduled_at',
  'post_note',
];
const PRIORITY_OPTIONS = ['low', 'medium', 'high', 'urgent'];
const STATUS_OPTIONS = ['open', 'resolved', 'closed', 'cancelled'];
const DEFAULT_VALUE_FOR_TYPE = {
  set_priority: 'medium',
  set_status: 'resolved',
  set_assignee: '',
  clear_due_date: null,
  clear_scheduled_at: null,
  post_note: '',
};

const actions = computed(() => props.modelValue || []);

const update = next => emit('update:modelValue', next);

const addAction = () => {
  update([...actions.value, { type: 'set_priority', value: 'medium' }]);
};

const removeAction = index => {
  update(actions.value.filter((_, position) => position !== index));
};

const setType = (index, type) => {
  update(
    actions.value.map((action, position) =>
      position === index ? { type, value: DEFAULT_VALUE_FOR_TYPE[type] } : action
    )
  );
};

const setValue = (index, value) => {
  update(
    actions.value.map((action, position) =>
      position === index ? { ...action, value } : action
    )
  );
};

const actionLabel = type =>
  t(`TICKET.SETTINGS.FORM.AUTOMATION.ACTION_TYPES.${type.toUpperCase()}`);
const actionHint = type =>
  t(`TICKET.SETTINGS.FORM.AUTOMATION.ACTION_HINTS.${type.toUpperCase()}`);
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      v-for="(action, index) in actions"
      :key="index"
      class="flex flex-col gap-2 p-2 border rounded-lg border-n-weak"
    >
      <div class="flex items-center gap-2">
        <select
          :value="action.type"
          class="mb-0"
          @change="setType(index, $event.target.value)"
        >
          <option v-for="type in ACTION_TYPES" :key="type" :value="type">
            {{ actionLabel(type) }}
          </option>
        </select>
        <NextButton
          v-tooltip.top="t('TICKET.SETTINGS.FORM.AUTOMATION.REMOVE_ACTION')"
          type="button"
          ruby
          ghost
          xs
          icon="i-lucide-trash-2"
          @click="removeAction(index)"
        />
      </div>

      <select
        v-if="action.type === 'set_priority'"
        :value="action.value"
        class="mb-0"
        @change="setValue(index, $event.target.value)"
      >
        <option
          v-for="option in PRIORITY_OPTIONS"
          :key="option"
          :value="option"
        >
          {{ t(`TICKET.FORM.PRIORITY.${option.toUpperCase()}`) }}
        </option>
      </select>

      <select
        v-else-if="action.type === 'set_status'"
        :value="action.value"
        class="mb-0"
        @change="setValue(index, $event.target.value)"
      >
        <option v-for="option in STATUS_OPTIONS" :key="option" :value="option">
          {{ t(`TICKET.STATUS.${option.toUpperCase()}`) }}
        </option>
      </select>

      <select
        v-else-if="action.type === 'set_assignee'"
        :value="action.value || ''"
        class="mb-0"
        @change="setValue(index, $event.target.value)"
      >
        <option value="">
          {{ t('TICKET.SETTINGS.FORM.AUTOMATION.UNASSIGN') }}
        </option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>

      <textarea
        v-else-if="action.type === 'post_note'"
        :value="action.value"
        rows="2"
        class="mb-0"
        :placeholder="t('TICKET.SETTINGS.FORM.AUTOMATION.NOTE_PLACEHOLDER')"
        @input="setValue(index, $event.target.value)"
      />

      <p v-else class="mb-0 text-xs text-n-slate-11">
        {{ actionHint(action.type) }}
      </p>
    </div>

    <NextButton
      type="button"
      slate
      faded
      sm
      icon="i-lucide-plus"
      :label="t('TICKET.SETTINGS.FORM.AUTOMATION.ADD_ACTION')"
      @click="addAction"
    />
  </div>
</template>
