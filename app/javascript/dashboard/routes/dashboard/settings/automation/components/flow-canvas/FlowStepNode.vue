<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { findCategory } from '../../flowSteps';
import {
  DEFAULT_HANDLE_ID,
  TARGET_HANDLE_ID,
  NODE_WIDTH,
  branchHandleId,
} from './flowGraph';

const props = defineProps({
  id: { type: String, required: true },
  data: { type: Object, required: true },
  selected: { type: Boolean, default: false },
});

const emit = defineEmits(['remove', 'open']);

defineOptions({ inheritAttrs: false });

const { t } = useI18n();

const step = computed(() => props.data.step);
const definition = computed(() => props.data.definition);
const category = computed(() => findCategory(definition.value?.category));

const label = computed(() =>
  t(`AUTOMATION.FLOW.STEP.${step.value.type.toUpperCase()}`)
);

// So o primeiro campo de texto longo (normalmente a mensagem pro cliente) -
// e o que mais ajuda a reconhecer a etapa sem abrir o painel de edicao.
const previewField = computed(() =>
  (definition.value?.fields || []).find(
    field => field.kind === 'textarea' || field.key === 'content'
  )
);
const previewText = computed(() => {
  const field = previewField.value;
  if (!field) return '';
  return step.value.params?.[field.key] || '';
});

const branches = computed(() => definition.value?.branches || []);

// Sempre existe uma saida "padrao" (a proxima etapa), e mais uma por ramo. Com
// apenas uma saida, o rotulo ao lado do conector some - so tem um caminho
// possivel, nomea-lo so deixaria o card mais cheio sem ajudar em nada.
const outputs = computed(() => {
  const main = {
    id: DEFAULT_HANDLE_ID,
    label: branches.value.length ? t('AUTOMATION.FLOW.NEXT_STEP_SHORT') : '',
  };
  const branchOutputs = branches.value.map(branch => ({
    id: branchHandleId(branch),
    label: t(`AUTOMATION.FLOW.BRANCH.${branch.toUpperCase()}`),
  }));
  return [main, ...branchOutputs];
});

const topFor = index => `${((index + 1) / (outputs.value.length + 1)) * 100}%`;

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
    class="relative flex flex-col gap-2 p-3 rounded-xl border bg-n-solid-1 shadow-sm transition-all cursor-pointer group"
    :style="{ width: `${NODE_WIDTH}px` }"
    :class="
      selected
        ? 'border-n-blue-9 ring-2 ring-n-blue-5'
        : 'border-n-weak hover:border-n-slate-6'
    "
    @click="emit('open', id)"
  >
    <Handle
      :id="TARGET_HANDLE_ID"
      type="target"
      :position="Position.Left"
      class="!bg-n-slate-8 !border-n-slate-1"
    />

    <div class="flex items-start gap-2">
      <span
        class="flex items-center justify-center rounded-lg size-7 shrink-0"
        :class="colorClasses"
      >
        <Icon :icon="definition?.icon" class="size-4" />
      </span>
      <div class="flex flex-col min-w-0 grow">
        <span class="text-xs font-medium truncate text-n-slate-12">
          {{ label }}
        </span>
        <span class="text-xs text-n-slate-10">#{{ id }}</span>
      </div>
      <button
        type="button"
        class="nodrag p-1 rounded-md opacity-0 shrink-0 text-n-slate-10 hover:bg-n-ruby-3 hover:text-n-ruby-11 group-hover:opacity-100"
        :title="t('AUTOMATION.FLOW.REMOVE')"
        @mousedown.stop
        @click.stop="emit('remove', id)"
      >
        <Icon icon="i-lucide-trash-2" class="size-3.5" />
      </button>
    </div>

    <p
      v-if="previewText"
      class="text-xs leading-snug line-clamp-2 text-n-slate-11"
    >
      {{ previewText }}
    </p>

    <template v-for="(output, index) in outputs" :key="output.id">
      <Handle
        :id="output.id"
        type="source"
        :position="Position.Right"
        :style="{ top: topFor(index) }"
        class="!bg-n-blue-9 !border-n-slate-1"
      />
      <span
        v-if="output.label"
        class="absolute text-[10px] font-medium leading-none whitespace-nowrap px-1.5 py-0.5 rounded bg-n-amber-3 text-n-amber-11 ltr:left-full rtl:right-full ltr:ml-2 rtl:mr-2 -translate-y-1/2"
        :style="{ top: topFor(index) }"
      >
        {{ output.label }}
      </span>
    </template>
  </div>
</template>
