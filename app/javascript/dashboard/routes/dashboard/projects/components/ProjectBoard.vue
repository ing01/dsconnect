<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
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
  { key: 'pendente', label: 'Pending', color: 'slate' },
  { key: 'onboarding', label: 'Onboarding', color: 'blue' },
  { key: 'requisito', label: 'Requirements', color: 'amber' },
  { key: 'em_andamento', label: 'In Progress', color: 'teal' },
  { key: 'acompanhamento', label: 'Follow-up', color: 'violet' },
  { key: 'pos', label: 'Post', color: 'orange' },
];

const completedStages = [
  { key: 'finalizado', label: 'Completed', color: 'emerald' },
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
  <div class="flex flex-1 gap-4 overflow-x-auto min-h-0 pb-2">
    <ProjectBoardColumn
      v-for="stage in visibleStages"
      :key="stage.key"
      :stage="stage.key"
      :title="t(`PROJECTS.STAGES.${stage.key.toUpperCase()}`, stage.label)"
      :color="stage.color"
      :show-completed="showCompleted"
      :projects="getStageProjects(stage.key)"
      @open-project="emit('openProject', $event)"
      @move-project="emit('moveProject', $event)"
    />
  </div>
</template>
