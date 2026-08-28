<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { formatMesaName } from 'dashboard/helper/mesaName';

const props = defineProps({
  initialTeamId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['close', 'created', 'openAddModule']);

const { t } = useI18n();
const store = useStore();

const step = ref(1);
const isSubmitting = ref(false);

const name = ref('');
const companyId = ref(null);
const teamId = ref(props.initialTeamId);
const projectModuleId = ref(null);
const startDate = ref(new Date().toISOString().split('T')[0]);
const projectDueDate = ref('');

const tasksConfig = ref([]);

const teams = computed(() => store.getters['teams/getTeams'] || []);
const modules = computed(() => store.getters['projectModules/getModules'] || []);
const teamMembers = computed(() => {
  if (!teamId.value) return [];
  return store.getters['teamMembers/getTeamMembers'](teamId.value) || [];
});

const companies = computed(() => store.getters['companies/getCompanies'] || []);

onMounted(async () => {
  store.dispatch('teams/get');
  store.dispatch('projectModules/get');
  store.dispatch('companies/get', { page: 1 });
  if (teamId.value) {
    store.dispatch('teamMembers/get', { teamId: teamId.value });
  }
});

const onTeamChange = () => {
  if (teamId.value) {
    store.dispatch('teamMembers/get', { teamId: teamId.value });
  }
};

const isStep1Valid = computed(() => {
  return !!name.value.trim() && !!teamId.value;
});

const goToStep2 = () => {
  if (!isStep1Valid.value) return;

  const selectedModule = modules.value.find(m => m.id === projectModuleId.value);
  const templates = selectedModule?.task_templates || [];

  const baseDate = startDate.value ? new Date(startDate.value) : new Date();

  tasksConfig.value = templates.map(tmpl => {
    const due = new Date(baseDate);
    due.setDate(due.getDate() + (tmpl.due_days || 1));
    const dueFormatted = due.toISOString().split('T')[0];

    return {
      task_template_id: tmpl.id,
      name: tmpl.name,
      default_ticket_title: tmpl.default_ticket_title,
      description: tmpl.description,
      checklist: tmpl.checklist || [],
      due_days: tmpl.due_days,
      next_project_stage: tmpl.next_project_stage,
      assignee_id: tmpl.default_assignee_id || '',
      due_date: dueFormatted,
      scheduled_at: '',
    };
  });

  step.value = 2;
};

const goBackToStep1 = () => {
  step.value = 1;
};

const submitProject = async () => {
  if (isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    const projectPayload = {
      name: name.value.trim(),
      company_id: companyId.value || null,
      team_id: teamId.value,
      project_module_id: projectModuleId.value || null,
      start_date: startDate.value || null,
      due_date: projectDueDate.value || null,
      stage: 'pendente',
    };

    const createdProject = await store.dispatch('projects/create', projectPayload);

    if (tasksConfig.value.length > 0) {
      await store.dispatch('projects/generateTickets', {
        projectId: createdProject.id,
        tasks: tasksConfig.value.map(tConfig => ({
          task_template_id: tConfig.task_template_id,
          assignee_id: tConfig.assignee_id || null,
          due_date: tConfig.due_date ? `${tConfig.due_date}T00:00:00` : null,
          scheduled_at: tConfig.scheduled_at ? `${tConfig.scheduled_at}T00:00:00` : null,
        })),
      });
    }

    useAlert(t('PROJECTS.CREATE.SUCCESS'));
    emit('created', createdProject);
    emit('close');
  } catch (error) {
    useAlert(error.message || t('PROJECTS.CREATE.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="
        step === 1
          ? t('PROJECTS.CREATE.TITLE_STEP1')
          : t('PROJECTS.CREATE.TITLE_STEP2')
      "
    />

    <div class="flex-1 overflow-y-auto p-6 min-h-0">
      <!-- Step Indicator -->
      <div class="flex items-center gap-3 mb-6">
        <div class="flex items-center gap-2">
          <span
            class="flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold"
            :class="step === 1 ? 'bg-n-brand text-n-slate-1' : 'bg-n-teal-9 text-n-slate-1'"
          >
            {{ step === 1 ? '1' : '✓' }}
          </span>
          <span class="text-sm font-medium" :class="step === 1 ? 'text-n-slate-12' : 'text-n-slate-10'">
            {{ t('PROJECTS.FORM.NAME.LABEL') }}
          </span>
        </div>
        <div class="flex-1 h-px bg-n-weak" />
        <div class="flex items-center gap-2">
          <span
            class="flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold"
            :class="step === 2 ? 'bg-n-brand text-n-slate-1' : 'bg-n-slate-4 text-n-slate-11'"
          >
            2
          </span>
          <span class="text-sm font-medium" :class="step === 2 ? 'text-n-slate-12' : 'text-n-slate-10'">
            {{ t('PROJECTS.CREATE.TITLE_STEP2') }}
          </span>
        </div>
      </div>

      <!-- Step 1: Project Information -->
      <form v-if="step === 1" class="flex flex-col gap-5" @submit.prevent="goToStep2">
        <!-- Nome do Projeto -->
        <div class="flex flex-col gap-1.5">
          <NextInput
            v-model="name"
            :label="t('PROJECTS.FORM.NAME.LABEL')"
            :placeholder="t('PROJECTS.FORM.NAME.PLACEHOLDER')"
            required
          />
        </div>

        <!-- Cliente (Empresa) -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-12">
            {{ t('PROJECTS.FORM.COMPANY.LABEL') }}
          </label>
          <select
            v-model="companyId"
            class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
          >
            <option :value="null">{{ t('PROJECTS.FORM.COMPANY.NONE') }}</option>
            <option v-for="comp in companies" :key="comp.id" :value="comp.id">
              {{ comp.name }}
            </option>
          </select>
        </div>

        <!-- Mesa de Servico -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-12">
            {{ t('PROJECTS.FORM.TEAM.LABEL') }} <span class="text-n-ruby-11">*</span>
          </label>
          <select
            v-model="teamId"
            required
            class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            @change="onTeamChange"
          >
            <option :value="null">{{ t('PROJECTS.FORM.TEAM.SELECT') }}</option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ formatMesaName(team.name) }}
            </option>
          </select>
        </div>

        <!-- Modulo com atalho -->
        <div class="flex flex-col gap-1.5">
          <div class="flex items-center justify-between">
            <label class="text-xs font-medium text-n-slate-12">
              {{ t('PROJECTS.FORM.MODULE.LABEL') }}
            </label>
            <button
              type="button"
              class="text-xs text-n-teal-11 hover:underline flex items-center gap-1 font-medium"
              @click="emit('openAddModule')"
            >
              <Icon icon="i-lucide-plus" class="size-3" />
              {{ t('PROJECTS.FORM.MODULE.NEW_SHORTCUT') }}
            </button>
          </div>
          <select
            v-model="projectModuleId"
            class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
          >
            <option :value="null">{{ t('PROJECTS.FORM.MODULE.NONE') }}</option>
            <option v-for="mod in modules" :key="mod.id" :value="mod.id">
              {{ mod.name }} ({{ mod.task_templates?.length || 0 }} {{ t('PROJECTS.CARD.TASK_COUNT') }})
            </option>
          </select>
        </div>

        <!-- Datas: Inicio e Previsao -->
        <div class="grid grid-cols-2 gap-4">
          <NextInput
            v-model="startDate"
            type="date"
            :label="t('PROJECTS.FORM.START_DATE.LABEL')"
          />
          <NextInput
            v-model="projectDueDate"
            type="date"
            :label="t('PROJECTS.FORM.DUE_DATE.LABEL')"
          />
        </div>

        <!-- Modal Footer Step 1 -->
        <div class="flex justify-end gap-2 pt-5 border-t border-n-weak">
          <NextButton
            faded
            slate
            type="button"
            :label="t('PROJECTS.FORM.CANCEL')"
            @click="emit('close')"
          />
          <NextButton
            type="button"
            :label="t('PROJECTS.FORM.NEXT_STEP')"
            :disabled="!isStep1Valid"
            @click="goToStep2"
          />
        </div>
      </form>

      <!-- Step 2: Task configuration & review -->
      <div v-else class="flex flex-col gap-5">
        <div class="p-3 bg-n-alpha-1 rounded-lg border border-n-weak text-xs text-n-slate-11 flex items-center gap-2">
          <Icon icon="i-lucide-info" class="size-4 flex-shrink-0 text-n-teal-11" />
          <span>{{ t('PROJECTS.CREATE.STEP2_HINT') }}</span>
        </div>

        <div v-if="!tasksConfig.length" class="text-center py-8 text-n-slate-10 text-sm">
          {{ t('PROJECTS.CREATE.NO_TASKS_IN_MODULE') }}
        </div>

        <div v-else class="flex flex-col gap-3">
          <div
            v-for="(task, idx) in tasksConfig"
            :key="task.task_template_id"
            class="p-4 rounded-xl border border-n-weak bg-n-solid-1 flex flex-col gap-3"
          >
            <div class="flex items-start justify-between gap-2">
              <div>
                <h4 class="text-sm font-semibold text-n-slate-12">
                  {{ idx + 1 }}. {{ task.name }}
                </h4>
                <p v-if="task.default_ticket_title" class="text-xs text-n-slate-11 mt-0.5">
                  {{ t('PROJECTS.TASK.CALL_TITLE') }}: {{ task.default_ticket_title }}
                </p>
              </div>
              <span v-if="task.next_project_stage" class="text-[11px] px-2 py-0.5 rounded bg-n-teal-3 text-n-teal-11 font-medium flex-shrink-0">
                {{ t('PROJECTS.TASK.ADVANCES_TO') }}: {{ t(`PROJECTS.STAGES.${task.next_project_stage.toUpperCase()}`, task.next_project_stage) }}
              </span>
            </div>

            <!-- Checklist preview -->
            <div v-if="task.checklist && task.checklist.length" class="flex flex-wrap gap-1.5 text-xs text-n-slate-10">
              <span
                v-for="(chk, chkIdx) in task.checklist"
                :key="chkIdx"
                class="flex items-center gap-1 px-2 py-0.5 rounded bg-n-slate-3 text-[11px]"
              >
                <Icon icon="i-lucide-check-square" class="size-3 text-n-slate-9" />
                {{ chk.title || chk }}
              </span>
            </div>

            <!-- Fields: Responsavel & Vencimento -->
            <div class="grid grid-cols-2 gap-3 pt-3 border-t border-n-weak">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-n-slate-11">
                  {{ t('PROJECTS.TASK.ASSIGNEE') }}
                </label>
                <select
                  v-model="task.assignee_id"
                  class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
                >
                  <option value="">{{ t('PROJECTS.TASK.UNASSIGNED') }}</option>
                  <option v-for="agent in teamMembers" :key="agent.id" :value="agent.id">
                    {{ agent.name }}
                  </option>
                </select>
              </div>

              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-n-slate-11">
                  {{ t('PROJECTS.TASK.DUE_DATE') }}
                </label>
                <input
                  v-model="task.due_date"
                  type="date"
                  class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Modal Footer Step 2 -->
        <div class="flex justify-between items-center pt-5 border-t border-n-weak">
          <NextButton
            faded
            slate
            type="button"
            :label="t('PROJECTS.FORM.BACK')"
            @click="goBackToStep1"
          />
          <div class="flex gap-2">
            <NextButton
              faded
              slate
              type="button"
              :label="t('PROJECTS.FORM.CANCEL')"
              @click="emit('close')"
            />
            <NextButton
              type="button"
              :label="t('PROJECTS.FORM.CONFIRM_AND_GENERATE')"
              :is-loading="isSubmitting"
              @click="submitProject"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
