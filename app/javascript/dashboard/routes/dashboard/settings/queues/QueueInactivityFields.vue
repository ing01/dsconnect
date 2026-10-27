<script setup>
import { computed } from 'vue';

const props = defineProps({
  modelValue: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['update:modelValue']);

const MIN_MINUTES = 5;

const update = changes =>
  emit('update:modelValue', { ...props.modelValue, ...changes });

const nudgeEnabled = computed(() => props.modelValue.nudgeAfter !== null);
const closeEnabled = computed(() => props.modelValue.closeAfter !== null);

const toMinutes = event => {
  const minutes = parseInt(event.target.value, 10);
  return Number.isNaN(minutes) ? MIN_MINUTES : minutes;
};
</script>

<template>
  <div class="flex flex-col w-full gap-4 pt-2">
    <div class="flex flex-col gap-1">
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.TITLE') }}
      </h4>
      <p class="text-xs text-n-slate-11">
        {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.DESCRIPTION') }}
      </p>
    </div>

    <div class="flex flex-col gap-2">
      <label class="flex items-center gap-2">
        <input
          type="checkbox"
          :checked="nudgeEnabled"
          @change="
            update({ nudgeAfter: $event.target.checked ? MIN_MINUTES : null })
          "
        />
        {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.NUDGE.ENABLE') }}
      </label>
      <template v-if="nudgeEnabled">
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.NUDGE.AFTER') }}
          <input
            type="number"
            :min="MIN_MINUTES"
            :value="modelValue.nudgeAfter"
            @input="update({ nudgeAfter: toMinutes($event) })"
          />
        </label>
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.NUDGE.MESSAGE') }}
          <textarea
            rows="2"
            :value="modelValue.nudgeMessage"
            :placeholder="
              $t('QUEUES_SETTINGS.FORM.INACTIVITY.NUDGE.PLACEHOLDER')
            "
            @input="update({ nudgeMessage: $event.target.value })"
          />
        </label>
      </template>
    </div>

    <div class="flex flex-col gap-2">
      <label class="flex items-center gap-2">
        <input
          type="checkbox"
          :checked="closeEnabled"
          @change="
            update({ closeAfter: $event.target.checked ? MIN_MINUTES : null })
          "
        />
        {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.CLOSE.ENABLE') }}
      </label>
      <template v-if="closeEnabled">
        <label>
          {{
            nudgeEnabled
              ? $t('QUEUES_SETTINGS.FORM.INACTIVITY.CLOSE.AFTER_NUDGE')
              : $t('QUEUES_SETTINGS.FORM.INACTIVITY.CLOSE.AFTER_MESSAGE')
          }}
          <input
            type="number"
            :min="MIN_MINUTES"
            :value="modelValue.closeAfter"
            @input="update({ closeAfter: toMinutes($event) })"
          />
        </label>
        <label>
          {{ $t('QUEUES_SETTINGS.FORM.INACTIVITY.CLOSE.MESSAGE') }}
          <textarea
            rows="2"
            :value="modelValue.closeMessage"
            :placeholder="
              $t('QUEUES_SETTINGS.FORM.INACTIVITY.CLOSE.PLACEHOLDER')
            "
            @input="update({ closeMessage: $event.target.value })"
          />
        </label>
      </template>
    </div>
  </div>
</template>
