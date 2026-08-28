<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ProjectBoardColumn from './ProjectBoardColumn.vue';

const props = defineProps({
  projects: {
    type: Array,
    default: () => [],
  },
  showCompleted: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['openProject', 'moveProject']);

const { t } = useI18n();

const defaultStages = [
  { key: 'pendente', label: 'Pendente' },
  { key: 'onboarding', label: 'Onboarding' },
  { key: 'requisito', label: 'Requisito' },
  { key: 'em_andamento', label: 'Em Andamento' },
  { key: 'acompanhamento', label: 'Acompanhamento' },
  { key: 'pos', label: 'Pós' },
];

const completedStages = [
  { key: 'finalizado', label: 'Finalizado' },
];

const visibleStages = computed(() => {
  if (props.showCompleted) {
    return [...defaultStages, ...completedStages];
  }
  return defaultStages;
});

const getStageProjects = stageKey => {
  return props.projects.filter(p => p.stage === stageKey);
};
</script>

<template>
  <div class="flex flex-1 gap-3 overflow-x-auto min-h-0 pb-2">
    <ProjectBoardColumn
      v-for="stage in visibleStages"
      :key="stage.key"
      :stage="stage.key"
      :title="t(`PROJECTS.STAGES.${stage.key.toUpperCase()}`, stage.label)"
      :projects="getStageProjects(stage.key)"
      @open-project="emit('openProject', $event)"
      @move-project="emit('moveProject', $event)"
    />
  </div>
</template>
