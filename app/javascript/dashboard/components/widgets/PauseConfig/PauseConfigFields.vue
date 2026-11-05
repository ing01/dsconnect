<script setup>
import { useI18n } from 'vue-i18n';
import { PAUSE_NUMBERS, PAUSE_TOGGLES, PAUSE_MESSAGES } from './pauseConfig';

const props = defineProps({
  modelValue: { type: Object, required: true },
});
const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const update = changes =>
  emit('update:modelValue', { ...props.modelValue, ...changes });

const label = (group, key) => t(`INBOX_MGMT.INACTIVITY.PAUSE.${group}.${key}`);
</script>

<template>
  <div class="flex flex-col w-full gap-4 pt-2">
    <h4 class="text-sm font-medium text-n-slate-12">
      {{ t('INBOX_MGMT.INACTIVITY.PAUSE.SECTION') }}
    </h4>

    <div
      v-for="toggle in PAUSE_TOGGLES"
      :key="toggle.key"
      class="flex flex-col gap-1"
    >
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input
          type="checkbox"
          class="!m-0"
          :checked="modelValue[toggle.key]"
          @change="update({ [toggle.key]: $event.target.checked })"
        />
        {{ label(toggle.label, 'LABEL') }}
      </label>
      <p class="text-xs text-n-slate-11">{{ label(toggle.label, 'HELP') }}</p>
    </div>

    <template v-if="modelValue.pause_enabled">
      <label
        v-for="key in PAUSE_NUMBERS"
        :key="key"
        class="flex flex-col gap-1 text-sm text-n-slate-12"
      >
        {{ label(key.toUpperCase(), 'LABEL') }}
        <input
          type="number"
          min="1"
          :value="modelValue[key]"
          @input="update({ [key]: $event.target.value })"
        />
        <span class="text-xs text-n-slate-11">
          {{ label(key.toUpperCase(), 'HELP') }}
        </span>
      </label>

      <p class="text-xs text-n-slate-11">
        {{ t('INBOX_MGMT.INACTIVITY.PAUSE.MESSAGES_HELP') }}
      </p>
      <label
        v-for="key in PAUSE_MESSAGES"
        :key="key"
        class="flex flex-col gap-1 text-sm text-n-slate-12"
      >
        {{ t(`INBOX_MGMT.INACTIVITY.PAUSE.${key.toUpperCase()}`) }}
        <textarea
          rows="2"
          :value="modelValue[key]"
          @input="update({ [key]: $event.target.value })"
        />
      </label>
    </template>
  </div>
</template>
