<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  BaseEdge,
  EdgeLabelRenderer,
  Position,
  getBezierPath,
} from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  id: { type: String, required: true },
  sourceX: { type: Number, required: true },
  sourceY: { type: Number, required: true },
  targetX: { type: Number, required: true },
  targetY: { type: Number, required: true },
  sourcePosition: { type: String, default: Position.Right },
  targetPosition: { type: String, default: Position.Left },
  markerEnd: { type: String, default: undefined },
  data: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['remove']);

defineOptions({ inheritAttrs: false });

const { t } = useI18n();

// O gatilho e so contexto visual (nao existe em `steps`), entao sua ligacao
// nao tem botao de desconectar nem rotulo - as outras duas vem direto do que
// o passo configurou: `next` (unica, sem nome) ou um ramo (`branches`, com o
// nome da condicao).
const kind = computed(() => props.data?.kind);
const isBranch = computed(() => kind.value === 'branch');
const isTrigger = computed(() => kind.value === 'trigger');

const path = computed(() =>
  getBezierPath({
    sourceX: props.sourceX,
    sourceY: props.sourceY,
    sourcePosition: props.sourcePosition,
    targetX: props.targetX,
    targetY: props.targetY,
    targetPosition: props.targetPosition,
  })
);

const branchLabel = computed(() =>
  isBranch.value
    ? t(`AUTOMATION.FLOW.BRANCH.${props.data.branch.toUpperCase()}`)
    : ''
);

const strokeClass = computed(() => {
  if (isTrigger.value) return 'stroke-n-slate-7';
  if (isBranch.value) return 'stroke-n-amber-9';
  return 'stroke-n-blue-9';
});
</script>

<template>
  <BaseEdge
    :id="id"
    :path="path[0]"
    :marker-end="markerEnd"
    class="!stroke-2"
    :class="strokeClass"
    :style="isTrigger ? { strokeDasharray: '4 4' } : null"
  />

  <EdgeLabelRenderer v-if="!isTrigger">
    <div
      class="absolute flex items-center gap-1 nodrag nopan pointer-events-auto"
      :style="{
        transform: `translate(-50%, -50%) translate(${path[1]}px, ${path[2]}px)`,
      }"
    >
      <span
        v-if="branchLabel"
        class="text-[10px] font-medium leading-none whitespace-nowrap px-1.5 py-0.5 rounded bg-n-amber-3 text-n-amber-11"
      >
        {{ branchLabel }}
      </span>
      <button
        type="button"
        class="flex items-center justify-center rounded-full size-4 shrink-0 bg-n-slate-4 text-n-slate-11 hover:bg-n-ruby-4 hover:text-n-ruby-11"
        :title="t('AUTOMATION.FLOW.CANVAS.DISCONNECT')"
        @click="emit('remove', id)"
      >
        <Icon icon="i-lucide-x" class="size-2.5" />
      </button>
    </div>
  </EdgeLabelRenderer>
</template>
