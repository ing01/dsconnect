<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  projectId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['close', 'updated']);

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const isLoading = ref(true);
const project = computed(() => store.getters['projects/getSelectedProject']);
const accountId = computed(() => store.getters['getCurrentAccountId']);

const stages = [
  { key: 'pendente', label: 'Pending', color: 'slate' },
  { key: 'onboarding', label: 'Onboarding', color: 'blue' },
  { key: 'requisito', label: 'Requirements', color: 'amber' },
  { key: 'em_andamento', label: 'In Progress', color: 'teal' },
  { key: 'acompanhamento', label: 'Follow-up', color: 'violet' },
  { key: 'pos', label: 'Post', color: 'orange' },
  { key: 'finalizado', label: 'Completed', color: 'emerald' },
];

onMounted(async () => {
  try {
    await store.dispatch('projects/show', props.projectId);
  } finally {
    isLoading.value = false;
  }
});

const onStageChange = async newStage => {
  try {
    await store.dispatch('projects/update', {
      id: props.projectId,
      stage: newStage,
    });
    useAlert(t('PROJECTS.DETAIL.STAGE_UPDATED'));
    emit('updated');
  } catch (error) {
    useAlert(error.message || t('PROJECTS.DETAIL.UPDATE_ERROR'));
  }
};

const openTicket = ticket => {
  emit('close');
  router.push(frontendURL(`accounts/${accountId.value}/tickets/${ticket.id}`));
};

const currentStageColor = computed(() => {
  const stage = stages.find(s => s.key === project.value?.stage);
  return stage?.color || 'slate';
});
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="project?.name || t('PROJECTS.DETAIL.TITLE')"
    />

    <div v-if="isLoading" class="flex items-center justify-center p-12">
      <span class="text-sm text-n-slate-10">{{ t('PROJECTS.DETAIL.LOADING') }}</span>
    </div>

    <div v-else-if="project" class="flex-1 overflow-y-auto p-6 flex flex-col gap-5 min-h-0">
      <!-- Top info bar -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.COMPANY.LABEL') }}</span>
          <span class="text-sm font-medium text-n-slate-12">{{ project.company_name || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.TEAM.LABEL') }}</span>
          <span class="text-sm font-medium text-n-slate-12">{{ project.team_name || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.MODULE.LABEL') }}</span>
          <span class="text-sm font-medium text-n-slate-12">{{ project.project_module_name || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.DETAIL.STAGE') }}</span>
          <select
            :value="project.stage"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 font-medium focus:border-n-brand focus:outline-none w-full"
            @change="onStageChange($event.target.value)"
          >
            <option v-for="st in stages" :key="st.key" :value="st.key">
              {{ t(`PROJECTS.STAGES.${st.key.toUpperCase()}`, st.label) }}
            </option>
          </select>
        </div>
      </div>

      <!-- Tickets list in this project -->
      <div class="flex flex-col gap-3">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t('PROJECTS.DETAIL.TASKS_LIST') }} ({{ project.tickets?.length || 0 }})
          </h4>
          <span class="text-xs text-n-slate-10">
            {{ project.completed_tickets_count || 0 }} {{ t('PROJECTS.DETAIL.COMPLETED') }}
          </span>
        </div>

        <div v-if="!project.tickets?.length" class="text-center py-8 text-sm text-n-slate-10 border border-dashed border-n-weak rounded-xl bg-n-alpha-1">
          {{ t('PROJECTS.DETAIL.NO_TASKS') }}
        </div>

        <div v-else class="flex flex-col gap-2">
          <div
            v-for="ticket in project.tickets"
            :key="ticket.id"
            class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-solid-1 hover:border-n-slate-6 hover:shadow-sm cursor-pointer transition-all"
            @click="openTicket(ticket)"
          >
            <div class="flex items-center gap-3 min-w-0">
              <span class="text-xs text-n-slate-10 font-mono">#{{ ticket.display_id || ticket.id }}</span>
              <span class="text-sm font-medium text-n-slate-12 truncate">{{ ticket.title }}</span>
            </div>

            <div class="flex items-center gap-2 flex-shrink-0">
              <span v-if="ticket.assignee_name" class="text-xs text-n-slate-11">
                {{ ticket.assignee_name }}
              </span>
              <WootLabel
                :label="ticket.status"
                :color="ticket.status === 'resolved' || ticket.status === 'closed' ? 'teal' : 'slate'"
                compact
              />
              <Icon icon="i-lucide-chevron-right" class="size-4 text-n-slate-9" />
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex justify-end pt-4 border-t border-n-weak">
        <NextButton
          faded
          slate
          type="button"
          :label="t('PROJECTS.FORM.CLOSE')"
          @click="emit('close')"
        />
      </div>
    </div>
  </div>
</template>
