<script setup>
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { VueFlow, Panel } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import Button from 'dashboard/components-next/button/Button.vue';
import WhatsappTriageWizard from './WhatsappTriageWizard.vue';
import FlowStepNode from './flow-canvas/FlowStepNode.vue';
import FlowTriggerNode from './flow-canvas/FlowTriggerNode.vue';
import FlowConnector from './flow-canvas/FlowConnector.vue';
import FlowStepPalette from './flow-canvas/FlowStepPalette.vue';
import FlowStepInspector from './flow-canvas/FlowStepInspector.vue';
import {
  autoLayoutPositions,
  buildNodes,
  buildEdges,
  DEFAULT_HANDLE_ID,
  TRIGGER_NODE_ID,
} from './flow-canvas/flowGraph';
import { findStepType, buildStep, variablesFor } from '../flowSteps';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  // Os cadastros que as etapas escolhem. Vem de fora porque sao os mesmos do
  // resto do sistema - nao ha lista propria da automacao.
  teams: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  categories: { type: Array, default: () => [] },
  captainAssistants: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const steps = computed(() => props.modelValue || []);
const variables = computed(() => variablesFor(steps.value));

const update = next => emit('update:modelValue', next);

const selectedStepId = ref(null);
const selectedStep = computed(
  () => steps.value.find(step => step.id === selectedStepId.value) || null
);
const selectedDefinition = computed(
  () => findStepType(selectedStep.value?.type) || { fields: [], branches: [] }
);

// Todo passo pode apontar pra qualquer outro, menos pra si mesmo - o caminho
// mais curto pra um laco infinito.
const targets = computed(() =>
  steps.value
    .filter(step => step.id !== selectedStepId.value)
    .map(step => ({
      value: step.id,
      label: `${step.id} · ${t(`AUTOMATION.FLOW.STEP.${step.type.toUpperCase()}`)}`,
    }))
);

const autoPositions = computed(() => autoLayoutPositions(steps.value));
const nodes = computed(() =>
  buildNodes(steps.value, {
    autoPositions: autoPositions.value,
    selectedId: selectedStepId.value,
  })
);
const edges = computed(() => buildEdges(steps.value));

const isValidConnection = connection => connection.source !== connection.target;

const patchStep = (id, changes) => {
  update(
    steps.value.map(step => (step.id === id ? { ...step, ...changes } : step))
  );
};

const patchParam = (id, key, value) => {
  const step = steps.value.find(candidate => candidate.id === id);
  if (!step) return;
  patchStep(id, { params: { ...(step.params || {}), [key]: value } });
};

const patchNext = (id, value) => patchStep(id, { next: value || null });

const patchBranch = (id, branch, value) => {
  const step = steps.value.find(candidate => candidate.id === id);
  if (!step) return;
  patchStep(id, {
    branches: { ...(step.branches || {}), [branch]: value || null },
  });
};

// A nova etapa encadeia na selecionada (se ela ainda nao seguir pra lugar
// nenhum) ou na ultima da lista - o caso comum e uma etapa depois da outra, e
// quem quiser outro caminho conecta a mao no diagrama.
const addStep = type => {
  const next = [...steps.value];
  const created = buildStep(type, next);

  const chainFrom =
    (selectedStep.value && !selectedStep.value.next
      ? selectedStep.value
      : null) || (!next.length ? null : next[next.length - 1]);

  if (chainFrom && !chainFrom.next) {
    const index = next.findIndex(step => step.id === chainFrom.id);
    next[index] = { ...chainFrom, next: created.id };
  }

  update([...next, created]);
  selectedStepId.value = created.id;
};

const removeStep = id => {
  const next = steps.value
    .filter(step => step.id !== id)
    // Quem apontava pra etapa removida fica sem destino, e nao apontando pro
    // vazio: um `next` pra um id inexistente derruba a execucao.
    .map(step => ({
      ...step,
      next: step.next === id ? null : step.next,
      branches: Object.fromEntries(
        Object.entries(step.branches || {}).map(([key, value]) => [
          key,
          value === id ? null : value,
        ])
      ),
    }));

  if (selectedStepId.value === id) selectedStepId.value = null;
  update(next);
};

const onConnect = connection => {
  const { source, sourceHandle, target } = connection;
  if (source === TRIGGER_NODE_ID) return; // o gatilho nao e editavel

  if (sourceHandle === DEFAULT_HANDLE_ID) {
    patchNext(source, target);
  } else if (sourceHandle?.startsWith('branch__')) {
    patchBranch(source, sourceHandle.replace('branch__', ''), target);
  }
};

const onNodeDragStop = ({ node }) => {
  if (node.type !== 'step') return;
  patchStep(node.id, { ui_position: node.position });
};

const disconnectEdge = edgeId => {
  const edge = edges.value.find(candidate => candidate.id === edgeId);
  if (!edge?.data) return;

  if (edge.data.kind === 'next') patchNext(edge.data.stepId, null);
  else if (edge.data.kind === 'branch') {
    patchBranch(edge.data.stepId, edge.data.branch, null);
  }
};

// Reorganiza tudo pelo layout automatico - util depois de um monte de ajustes
// manuais, ou pra desfazer uma etapa que alguem arrastou pra um canto ruim.
const reorganize = () => {
  const positions = autoPositions.value;
  update(
    steps.value.map(step => ({ ...step, ui_position: positions[step.id] }))
  );
};
</script>

<template>
  <section class="flex flex-col gap-3">
    <div class="flex items-center justify-between gap-2">
      <div>
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('AUTOMATION.FLOW.TITLE') }}
        </h4>
        <p class="text-xs text-n-slate-10">
          {{ t('AUTOMATION.FLOW.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <WhatsappTriageWizard :steps-count="steps.length" @apply="update" />

    <!-- Com zero etapas o canvas nao aparece - mas a paleta de etapas
         continua disponivel aqui, senao nao haveria nenhum jeito manual de
         criar a primeira. -->
    <div v-if="!steps.length" class="flex items-center gap-3">
      <p class="text-sm text-n-slate-10">{{ t('AUTOMATION.FLOW.EMPTY') }}</p>
      <FlowStepPalette @add="addStep" />
    </div>

    <div
      v-else
      class="relative overflow-hidden border rounded-xl border-n-weak h-[32rem]"
    >
      <VueFlow
        :nodes="nodes"
        :edges="edges"
        :min-zoom="0.3"
        :max-zoom="1.5"
        :delete-key-code="null"
        :edges-updatable="false"
        :is-valid-connection="isValidConnection"
        default-marker-color="#64748b"
        fit-view-on-init
        @connect="onConnect"
        @node-drag-stop="onNodeDragStop"
        @pane-click="selectedStepId = null"
      >
        <template #node-step="nodeProps">
          <FlowStepNode
            v-bind="nodeProps"
            @open="selectedStepId = $event"
            @remove="removeStep"
          />
        </template>
        <template #node-trigger="nodeProps">
          <FlowTriggerNode v-bind="nodeProps" />
        </template>
        <template #edge-flowConnector="edgeProps">
          <FlowConnector v-bind="edgeProps" @remove="disconnectEdge" />
        </template>

        <Background :gap="24" pattern-color="#9ca3af" />
        <Controls :show-interactive="false" />
        <Panel position="top-right" class="flex gap-2">
          <Button
            v-tooltip="t('AUTOMATION.FLOW.CANVAS.REORGANIZE')"
            icon="i-lucide-layout-grid"
            size="sm"
            variant="faded"
            color="slate"
            @click="reorganize"
          />
          <FlowStepPalette @add="addStep" />
        </Panel>
      </VueFlow>

      <FlowStepInspector
        v-if="selectedStep"
        :step="selectedStep"
        :definition="selectedDefinition"
        :teams="teams"
        :columns="columns"
        :categories="categories"
        :captain-assistants="captainAssistants"
        :variables="variables"
        :targets="targets"
        @update-param="(key, value) => patchParam(selectedStep.id, key, value)"
        @update-next="value => patchNext(selectedStep.id, value)"
        @update-branch="
          (branch, value) => patchBranch(selectedStep.id, branch, value)
        "
        @remove="removeStep(selectedStep.id)"
        @close="selectedStepId = null"
      />
    </div>
  </section>
</template>
