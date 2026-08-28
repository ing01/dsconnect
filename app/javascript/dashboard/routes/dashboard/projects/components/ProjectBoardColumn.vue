<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import ProjectCard from './ProjectCard.vue';

const props = defineProps({
  stage: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  color: {
    type: String,
    default: 'slate',
  },
  showCompleted: {
    type: Boolean,
    default: false,
  },
  projects: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['openProject', 'moveProject']);

const { t } = useI18n();

const count = computed(() => props.projects.length);

const colorClasses = computed(() => {
  const map = {
    slate: 'bg-n-slate-9',
    blue: 'bg-n-blue-9',
    amber: 'bg-n-amber-9',
    teal: 'bg-n-teal-9',
    violet: 'bg-n-violet-9',
    orange: 'bg-n-orange-9',
    emerald: 'bg-n-emerald-9',
  };
  return map[props.color] || map.slate;
});

const onChange = evt => {
  if (evt.added) {
    emit('moveProject', {
      project: evt.added.element,
      newStage: props.stage,
    });
  }
};
</script>

<template>
  <div class="flex flex-col flex-shrink-0 w-72 rounded-xl bg-n-slate-2/60 border border-n-weak max-h-full">
    <!-- Header -->
    <div class="flex items-center justify-between px-3 py-2.5 border-b border-n-weak">
      <div class="flex items-center gap-2 min-w-0">
        <span class="w-2 h-2 rounded-full flex-shrink-0" :class="colorClasses" />
        <span class="text-sm font-semibold text-n-slate-12 truncate">
          {{ title }}
        </span>
        <span
          class="flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-full bg-n-slate-4 text-[11px] font-medium text-n-slate-11"
        >
          {{ count }}
        </span>
      </div>
    </div>

    <!-- Cards container with drag and drop -->
    <div class="flex-1 overflow-y-auto p-2 min-h-0">
      <Draggable
        :list="projects"
        group="projects"
        item-key="id"
        class="flex flex-col gap-2 min-h-[50px]"
        ghost-class="opacity-50"
        @change="onChange"
      >
        <template #item="{ element }">
          <ProjectCard
            :project="element"
            @click="emit('openProject', element)"
          />
        </template>
      </Draggable>

      <div v-if="!count" class="flex items-center justify-center py-8 text-center text-n-slate-10 text-xs">
        {{ showCompleted ? t('PROJECTS.EMPTY.NO_COMPLETED') : t('PROJECTS.EMPTY.NO_PROJECTS') }}
      </div>
    </div>
  </div>
</template>
