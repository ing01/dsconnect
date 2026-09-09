<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import WhatsappTriageWizard from './WhatsappTriageWizard.vue';
import {
  FLOW_STEP_TYPES,
  findStepType,
  buildStep,
  variablesFor,
} from '../flowSteps';

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

const label = key => t(`AUTOMATION.FLOW.STEP.${key.toUpperCase()}`);

const fieldsFor = step => findStepType(step.type)?.fields || [];
const branchesFor = step => findStepType(step.type)?.branches || [];

// Toda etapa pode apontar para qualquer outra, menos para si mesma - o caminho
// mais curto para um laco infinito.
const targetsFor = step =>
  steps.value
    .filter(candidate => candidate.id !== step.id)
    .map(candidate => ({
      value: candidate.id,
      label: `${candidate.id} · ${label(candidate.type)}`,
    }));

const optionsFor = field => {
  if (field.source) return props[field.source] || [];

  return (field.options || []).map(option => ({
    value: option,
    label: t(`AUTOMATION.FLOW.OPTION.${option.toUpperCase()}`),
  }));
};

const addStep = type => {
  if (!type) return;

  const next = [...steps.value];
  const created = buildStep(type, next);
  // Encadeia na ultima: o caso comum e uma etapa depois da outra, e quem quiser
  // outro caminho muda o destino no proprio campo.
  const last = next[next.length - 1];
  if (last && !last.next && !branchesFor(last).length) last.next = created.id;

  update([...next, created]);
};

const removeStep = index => {
  const removed = steps.value[index];
  const next = steps.value
    .filter((_, position) => position !== index)
    // Quem apontava para a etapa removida fica sem destino, e nao apontando
    // para o vazio: um `next` para um id inexistente derruba a execucao.
    .map(step => ({
      ...step,
      next: step.next === removed.id ? null : step.next,
      branches: Object.fromEntries(
        Object.entries(step.branches || {}).map(([key, value]) => [
          key,
          value === removed.id ? null : value,
        ])
      ),
    }));

  update(next);
};

const moveStep = (index, offset) => {
  const target = index + offset;
  if (target < 0 || target >= steps.value.length) return;

  const next = [...steps.value];
  [next[index], next[target]] = [next[target], next[index]];
  update(next);
};

const patch = (index, changes) => {
  const next = steps.value.map((step, position) =>
    position === index ? { ...step, ...changes } : step
  );
  update(next);
};

const setParam = (index, key, value) => {
  const step = steps.value[index];
  patch(index, { params: { ...(step.params || {}), [key]: value } });
};

const setBranch = (index, key, value) => {
  const step = steps.value[index];
  patch(index, {
    branches: { ...(step.branches || {}), [key]: value || null },
  });
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
      <select
        class="mb-0 text-sm w-52"
        value=""
        @change="
          addStep($event.target.value);
          $event.target.value = '';
        "
      >
        <option value="">{{ t('AUTOMATION.FLOW.ADD_STEP') }}</option>
        <option
          v-for="definition in FLOW_STEP_TYPES"
          :key="definition.type"
          :value="definition.type"
        >
          {{ label(definition.type) }}
        </option>
      </select>
    </div>

    <WhatsappTriageWizard
      :has-existing-steps="steps.length > 0"
      @apply="update"
    />

    <p v-if="!steps.length" class="text-sm text-n-slate-10">
      {{ t('AUTOMATION.FLOW.EMPTY') }}
    </p>

    <div
      v-for="(step, index) in steps"
      :key="step.id"
      class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak bg-n-alpha-black2"
    >
      <div class="flex items-center gap-2">
        <span
          class="px-1.5 py-0.5 text-xs rounded bg-n-alpha-2 text-n-slate-11 font-medium"
        >
          {{ step.id }}
        </span>
        <span class="text-sm font-medium text-n-slate-12">
          {{ label(step.type) }}
        </span>
        <div class="flex items-center gap-1 ml-auto">
          <button
            type="button"
            class="p-1 rounded text-n-slate-11 hover:bg-n-alpha-2"
            :title="t('AUTOMATION.FLOW.MOVE_UP')"
            @click="moveStep(index, -1)"
          >
            <Icon icon="i-lucide-arrow-up" class="size-4" />
          </button>
          <button
            type="button"
            class="p-1 rounded text-n-slate-11 hover:bg-n-alpha-2"
            :title="t('AUTOMATION.FLOW.MOVE_DOWN')"
            @click="moveStep(index, 1)"
          >
            <Icon icon="i-lucide-arrow-down" class="size-4" />
          </button>
          <button
            type="button"
            class="p-1 rounded text-n-ruby-11 hover:bg-n-alpha-2"
            :title="t('AUTOMATION.FLOW.REMOVE')"
            @click="removeStep(index)"
          >
            <Icon icon="i-lucide-trash-2" class="size-4" />
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label
          v-for="field in fieldsFor(step)"
          :key="field.key"
          class="flex flex-col gap-1 min-w-0"
          :class="field.kind === 'textarea' ? 'sm:col-span-2' : ''"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ t(`AUTOMATION.FLOW.FIELD.${field.key.toUpperCase()}`) }}
            <span v-if="field.required" class="text-n-ruby-11">*</span>
          </span>

          <textarea
            v-if="field.kind === 'textarea'"
            rows="2"
            class="w-full mb-0 text-sm"
            :value="step.params?.[field.key] || ''"
            @input="setParam(index, field.key, $event.target.value)"
          />
          <select
            v-else-if="field.kind === 'select'"
            class="w-full mb-0 text-sm"
            :value="step.params?.[field.key] ?? ''"
            @change="setParam(index, field.key, $event.target.value)"
          >
            <option value="">
              {{ t('AUTOMATION.FLOW.NOT_SET') }}
            </option>
            <option
              v-for="option in optionsFor(field)"
              :key="option.value ?? option.id"
              :value="option.value ?? option.id"
            >
              {{ option.label ?? option.name }}
            </option>
          </select>
          <!-- Lista as variaveis que o proprio fluxo produz, para ninguem ter
               de decorar o nome nem descobrir por tentativa. -->
          <select
            v-else-if="field.kind === 'variable'"
            class="w-full mb-0 text-sm"
            :value="step.params?.[field.key] || ''"
            @change="setParam(index, field.key, $event.target.value)"
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
            @input="setParam(index, field.key, $event.target.value)"
          />
        </label>
      </div>

      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('AUTOMATION.FLOW.NEXT_STEP') }}
          </span>
          <select
            class="w-full mb-0 text-sm"
            :value="step.next || ''"
            @change="patch(index, { next: $event.target.value || null })"
          >
            <option value="">{{ t('AUTOMATION.FLOW.END') }}</option>
            <option
              v-for="target in targetsFor(step)"
              :key="target.value"
              :value="target.value"
            >
              {{ target.label }}
            </option>
          </select>
        </label>

        <!-- Os caminhos alternativos. Sem um destino aqui, o fluxo entrega o
             atendimento a uma pessoa em vez de seguir com dado faltando. -->
        <label
          v-for="branch in branchesFor(step)"
          :key="branch"
          class="flex flex-col gap-1 min-w-0"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ t(`AUTOMATION.FLOW.BRANCH.${branch.toUpperCase()}`) }}
          </span>
          <select
            class="w-full mb-0 text-sm"
            :value="step.branches?.[branch] || ''"
            @change="setBranch(index, branch, $event.target.value)"
          >
            <option value="">{{ t('AUTOMATION.FLOW.HANDOFF') }}</option>
            <option
              v-for="target in targetsFor(step)"
              :key="target.value"
              :value="target.value"
            >
              {{ target.label }}
            </option>
          </select>
        </label>
      </div>
    </div>
  </section>
</template>
