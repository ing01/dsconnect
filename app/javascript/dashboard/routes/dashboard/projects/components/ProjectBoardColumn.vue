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
  projects: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['openProject', 'moveProject']);

const { t } = useI18n();

const count = computed(() => props.projects.length);

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
  <div class="flex flex-col flex-shrink-0 w-72 rounded-xl bg-n-slate-2 max-h-full">
    <!-- Header -->
    <div class="flex items-center justify-between px-3 py-2.5 border-b border-n-weak">
      <div class="flex items-center gap-2 min-w-0">
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
    </div>
  </div>
</template>
