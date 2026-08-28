<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  project: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click', 'edit', 'delete']);

const { t } = useI18n();

const progressPercent = computed(() => {
  if (!props.project.tickets_count || props.project.tickets_count === 0) return 0;
  return Math.round(
    ((props.project.completed_tickets_count || 0) / props.project.tickets_count) * 100
  );
});

const formatDate = dateStr => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleDateString();
};

const stageBorderClass = computed(() => {
  const map = {
    pendente: 'border-l-n-slate-9',
    onboarding: 'border-l-n-blue-9',
    requisito: 'border-l-n-amber-9',
    em_andamento: 'border-l-n-teal-9',
    acompanhamento: 'border-l-n-violet-9',
    pos: 'border-l-n-orange-9',
    finalizado: 'border-l-n-emerald-9',
  };
  return map[props.project.stage] || 'border-l-n-slate-9';
});

const stageLabelColor = computed(() => {
  const map = {
    pendente: 'slate',
    onboarding: 'blue',
    requisito: 'amber',
    em_andamento: 'teal',
    acompanhamento: 'violet',
    pos: 'orange',
    finalizado: 'emerald',
  };
  return map[props.project.stage] || 'slate';
});
</script>

<template>
  <div
    class="group relative flex flex-col gap-2.5 rounded-xl border border-n-weak bg-n-solid-1 p-3.5 cursor-pointer transition-all hover:border-n-slate-6 hover:shadow-md hover:-translate-y-0.5 border-l-4"
    :class="stageBorderClass"
    @click="emit('click', project)"
  >
    <!-- Header: Project Name & Stage Badge -->
    <div class="flex items-start justify-between gap-2">
      <h3 class="text-sm font-semibold text-n-slate-12 line-clamp-2 leading-tight" :title="project.name">
        {{ project.name }}
      </h3>
      <WootLabel
        v-if="project.stage"
        :label="t(`PROJECTS.STAGES.${project.stage.toUpperCase()}`, project.stage)"
        :color="stageLabelColor"
        compact
      />
    </div>

    <!-- Company / Client -->
    <div v-if="project.company_name" class="flex items-center gap-1.5 text-xs text-n-slate-11">
      <Icon icon="i-lucide-building-2" class="size-3.5 flex-shrink-0 text-n-slate-9" />
      <span class="truncate" :title="project.company_name">{{ project.company_name }}</span>
    </div>

    <!-- Module & Team info -->
    <div class="flex items-center flex-wrap gap-x-3 gap-y-1 text-xs text-n-slate-10">
      <div v-if="project.project_module_name" class="flex items-center gap-1">
        <Icon icon="i-lucide-layers" class="size-3.5 text-n-slate-9" />
        <span class="truncate">{{ project.project_module_name }}</span>
      </div>
      <div v-if="project.team_name" class="flex items-center gap-1">
        <Icon icon="i-lucide-users" class="size-3.5 text-n-slate-9" />
        <span class="truncate">{{ project.team_name }}</span>
      </div>
    </div>

    <!-- Task Progress Bar -->
    <div v-if="project.tickets_count" class="flex flex-col gap-1.5 mt-1">
      <div class="flex justify-between text-[11px] text-n-slate-10">
        <span class="font-medium">{{ t('PROJECTS.CARD.TASKS_PROGRESS') }}</span>
        <span class="font-medium">{{ project.completed_tickets_count || 0 }}/{{ project.tickets_count }} ({{ progressPercent }}%)</span>
      </div>
      <div class="w-full h-2 bg-n-slate-4 rounded-full overflow-hidden">
        <div
          class="h-full bg-n-teal-9 transition-all duration-500 rounded-full"
          :style="{ width: `${progressPercent}%` }"
        />
      </div>
    </div>

    <!-- Dates footer -->
    <div v-if="project.due_date || project.start_date" class="flex items-center justify-between text-[11px] text-n-slate-10 pt-2 border-t border-n-weak">
      <span v-if="project.start_date" class="flex items-center gap-1">
        <Icon icon="i-lucide-calendar" class="size-3 text-n-slate-8" />
        {{ formatDate(project.start_date) }}
      </span>
      <span v-if="project.due_date" class="flex items-center gap-1 text-n-ruby-11 font-medium ml-auto">
        <Icon icon="i-lucide-clock" class="size-3 text-n-ruby-9" />
        {{ formatDate(project.due_date) }}
      </span>
    </div>
  </div>
</template>
