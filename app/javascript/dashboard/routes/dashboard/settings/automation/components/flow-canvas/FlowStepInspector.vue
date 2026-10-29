<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { findCategory } from '../../flowSteps';

const props = defineProps({
  step: { type: Object, required: true },
  definition: { type: Object, default: () => ({ fields: [], branches: [] }) },
  teams: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  categories: { type: Array, default: () => [] },
  captainAssistants: { type: Array, default: () => [] },
  variables: { type: Array, default: () => [] },
  // Os outros passos, para os seletores de destino que ficam como alternativa
  // a conectar arrastando no diagrama.
  targets: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'update-param',
  'update-next',
  'update-branch',
  'remove',
  'close',
]);

const { t } = useI18n();

const category = computed(() => findCategory(props.definition.category));
const label = computed(() =>
  t(`AUTOMATION.FLOW.STEP.${props.step.type.toUpperCase()}`)
);
const description = computed(() =>
  t(`AUTOMATION.FLOW.STEP_DESCRIPTION.${props.step.type.toUpperCase()}`)
);

const sourceMap = computed(() => ({
  teams: props.teams,
  columns: props.columns,
  categories: props.categories,
  captainAssistants: props.captainAssistants,
}));

const optionsFor = field => {
  if (field.source) return sourceMap.value[field.source] || [];
  return (field.options || []).map(option => ({
    value: option,
    label: t(`AUTOMATION.FLOW.OPTION.${option.toUpperCase()}`),
  }));
};

const colorClasses = computed(() => {
  const palette = {
    blue: 'bg-n-blue-3 text-n-blue-11',
    indigo: 'bg-n-indigo-3 text-n-indigo-11',
    amber: 'bg-n-amber-3 text-n-amber-11',
    teal: 'bg-n-teal-3 text-n-teal-11',
    violet: 'bg-n-violet-3 text-n-violet-11',
  };
  return palette[category.value.color] || palette.blue;
});
</script>

<template>
  <div
    class="absolute inset-y-0 ltr:right-0 rtl:left-0 z-10 flex flex-col w-80 border-l shadow-xl bg-n-solid-1 border-n-weak"
  >
    <header class="flex items-start gap-3 p-4 border-b border-n-weak">
      <span
        class="flex items-center justify-center rounded-lg size-8 shrink-0"
        :class="colorClasses"
      >
        <Icon :icon="definition.icon" class="size-4" />
      </span>
      <div class="flex flex-col min-w-0 grow">
        <span class="text-sm font-medium text-n-slate-12">{{ label }}</span>
        <span class="text-xs text-n-slate-10">#{{ step.id }}</span>
      </div>
      <button
        type="button"
        class="p-1 rounded-md shrink-0 text-n-slate-10 hover:bg-n-alpha-2"
        @click="emit('close')"
      >
        <Icon icon="i-lucide-x" class="size-4" />
      </button>
    </header>

    <div class="flex flex-col flex-1 gap-4 p-4 overflow-y-auto">
      <p class="text-xs text-n-slate-10">{{ description }}</p>

      <label
        v-for="field in definition.fields"
        :key="field.key"
        class="flex flex-col gap-1"
      >
        <span class="text-xs font-medium text-n-slate-11">
          {{ t(`AUTOMATION.FLOW.FIELD.${field.key.toUpperCase()}`) }}
          <span v-if="field.required" class="text-n-ruby-11">*</span>
        </span>

        <textarea
          v-if="field.kind === 'textarea'"
          rows="3"
          class="w-full mb-0 text-sm"
          :value="step.params?.[field.key] || ''"
          @input="emit('update-param', field.key, $event.target.value)"
        />
        <select
          v-else-if="field.kind === 'select'"
          class="w-full mb-0 text-sm"
          :value="step.params?.[field.key] ?? ''"
          @change="emit('update-param', field.key, $event.target.value)"
        >
          <option value="">{{ t('AUTOMATION.FLOW.NOT_SET') }}</option>
          <option
            v-for="option in optionsFor(field)"
            :key="option.value ?? option.id"
            :value="option.value ?? option.id"
          >
            {{ option.label ?? option.name }}
          </option>
        </select>
        <select
          v-else-if="field.kind === 'variable'"
          class="w-full mb-0 text-sm"
          :value="step.params?.[field.key] || ''"
          @change="emit('update-param', field.key, $event.target.value)"
        >
          <option value="">{{ t('AUTOMATION.FLOW.NOT_SET') }}</option>
          <option v-for="name in variables" :key="name" :value="name">
            {{ name }}
          </option>
        </select>
        <input
          v-else
          :type="field.kind === 'number' ? 'number' : 'text'"
          class="w-full mb-0 text-sm"
          :placeholder="field.placeholder || ''"
          :value="step.params?.[field.key] ?? ''"
          @input="emit('update-param', field.key, $event.target.value)"
        />
      </label>

      <div class="pt-3 border-t border-n-weak">
        <p class="pb-2 text-xs text-n-slate-10">
          {{ t('AUTOMATION.FLOW.CANVAS.CONNECT_HINT') }}
        </p>

        <label class="flex flex-col gap-1 pb-3">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('AUTOMATION.FLOW.NEXT_STEP') }}
          </span>
          <select
            class="w-full mb-0 text-sm"
            :value="step.next || ''"
            @change="emit('update-next', $event.target.value || null)"
          >
            <option value="">{{ t('AUTOMATION.FLOW.END') }}</option>
            <option
              v-for="target in targets"
              :key="target.value"
              :value="target.value"
            >
              {{ target.label }}
            </option>
          </select>
        </label>

        <label
          v-for="branch in definition.branches || []"
          :key="branch"
          class="flex flex-col gap-1 pb-3"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ t(`AUTOMATION.FLOW.BRANCH.${branch.toUpperCase()}`) }}
          </span>
          <select
            class="w-full mb-0 text-sm"
            :value="step.branches?.[branch] || ''"
            @change="emit('update-branch', branch, $event.target.value || null)"
          >
            <option value="">{{ t('AUTOMATION.FLOW.HANDOFF') }}</option>
            <option
              v-for="target in targets"
              :key="target.value"
              :value="target.value"
            >
              {{ target.label }}
            </option>
          </select>
        </label>
      </div>
    </div>

    <footer class="p-3 border-t border-n-weak">
      <Button
        icon="i-lucide-trash-2"
        color="ruby"
        variant="faded"
        size="sm"
        :label="t('AUTOMATION.FLOW.REMOVE')"
        class="w-full"
        @click="emit('remove')"
      />
    </footer>
  </div>
</template>
