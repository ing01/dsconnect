<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useCompaniesStore } from 'dashboard/stores/companies';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { formatMesaName } from 'dashboard/helper/mesaName';
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
const { checkPermissions } = usePolicy();
const companiesStore = useCompaniesStore();

const isLoading = ref(true);
const project = computed(() => store.getters['projects/getSelectedProject']);
const accountId = computed(() => store.getters['getCurrentAccountId']);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const teams = computed(() => store.getters['teams/getTeams'] || []);
const companies = computed(() => companiesStore.getCompaniesList || []);

// Nome, cliente, equipe e datas so podem ser alterados depois de criado por
// quem administra projetos - editar isso por engano muda de qual Empresa/Mesa
// o projeto e', o que afeta relatorios e permissoes de quem ja via o projeto.
const canManageProject = computed(() =>
  checkPermissions(['administrator', 'project_manage'])
);

const showCancelForm = ref(false);
const cancelReason = ref('');
const notes = ref('');
const supportEndsOn = ref('');
const contractSignedOn = ref('');
const completionType = ref('');
const editName = ref('');
const editCompanyId = ref(null);
const editTeamId = ref(null);
const editStartDate = ref('');
const editDueDate = ref('');

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
  store.dispatch('agents/get');
  if (canManageProject.value) {
    store.dispatch('teams/get');
    companiesStore.get({ page: 1 });
  }
  try {
    await store.dispatch('projects/show', props.projectId);
  } finally {
    isLoading.value = false;
  }
});

// O modal só recebe o projeto de forma assíncrona (getter da store) - os
// campos de texto/data livres precisam de um estado local próprio pra editar
// sem disparar uma request a cada tecla (diferente do <select> de etapa, que
// já salva sozinho no @change).
watch(
  project,
  updated => {
    if (!updated) return;
    notes.value = updated.notes || '';
    supportEndsOn.value = updated.support_ends_on || '';
    contractSignedOn.value = updated.contract_signed_on || '';
    completionType.value = updated.completion_type || '';
    editName.value = updated.name || '';
    editCompanyId.value = updated.company_id || null;
    editTeamId.value = updated.team_id || null;
    editStartDate.value = updated.start_date || '';
    editDueDate.value = updated.due_date || '';
  },
  { immediate: true }
);

const onStageChange = async newStage => {
  try {
    await store.dispatch('projects/update', {
      id: props.projectId,
      stage: newStage,
    });
    useAlert(t('PROJECTS.DETAIL.STAGE_UPDATED'));
    emit('updated');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.DETAIL.UPDATE_ERROR'));
  }
};

const saveField = async data => {
  try {
    await store.dispatch('projects/update', { id: props.projectId, ...data });
    emit('updated');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.DETAIL.UPDATE_ERROR'));
  }
};

const onImplementerChange = event => {
  const value = event.target.value;
  saveField({ implementer_id: value || null });
};

const saveNotes = () => saveField({ notes: notes.value });
const saveSupportEndsOn = () => saveField({ support_ends_on: supportEndsOn.value || null });
const saveContractSignedOn = () => saveField({ contract_signed_on: contractSignedOn.value || null });
const saveCompletionType = () => saveField({ completion_type: completionType.value || null });

const saveName = () => {
  const trimmed = editName.value.trim();
  if (!trimmed || trimmed === project.value?.name) return;
  saveField({ name: trimmed });
};
const saveCompany = () => saveField({ company_id: editCompanyId.value || null });
const saveTeam = () => saveField({ team_id: editTeamId.value });
const saveStartDate = () => saveField({ start_date: editStartDate.value || null });
const saveDueDate = () => saveField({ due_date: editDueDate.value || null });

const confirmCancel = async () => {
  if (!cancelReason.value.trim()) return;
  try {
    await store.dispatch('projects/cancel', { id: props.projectId, reason: cancelReason.value.trim() });
    useAlert(t('PROJECTS.DETAIL.CANCEL.SUCCESS'));
    showCancelForm.value = false;
    cancelReason.value = '';
    emit('updated');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.DETAIL.CANCEL.ERROR'));
  }
};

const reactivateProject = async () => {
  try {
    await store.dispatch('projects/reactivate', props.projectId);
    useAlert(t('PROJECTS.DETAIL.REACTIVATE.SUCCESS'));
    emit('updated');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.DETAIL.REACTIVATE.ERROR'));
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
      <!-- Nome do projeto: so quem administra projetos pode mudar - o nome
           ja aparece no cabecalho do modal para todo mundo. -->
      <div v-if="canManageProject" class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-12">{{ t('PROJECTS.FORM.NAME.LABEL') }}</label>
        <input
          v-model="editName"
          type="text"
          class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
          @blur="saveName"
        />
      </div>

      <!-- Top info bar. Cliente/Equipe so viram <select> editavel para quem
           administra projetos - mudar isso depois de criado afeta relatorios
           e quem enxerga o projeto, entao fica restrito. Etapa continua
           aberta a qualquer um, com mais largura (col-span-2) para o texto do
           estagio nao cortar. -->
      <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.COMPANY.LABEL') }}</span>
          <select
            v-if="canManageProject"
            v-model="editCompanyId"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 font-medium focus:border-n-brand focus:outline-none w-full"
            @change="saveCompany"
          >
            <option :value="null">{{ t('PROJECTS.FORM.COMPANY.NONE') }}</option>
            <option v-for="comp in companies" :key="comp.id" :value="comp.id">{{ comp.name }}</option>
          </select>
          <span v-else class="text-sm font-medium text-n-slate-12">{{ project.company_name || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.TEAM.LABEL') }}</span>
          <select
            v-if="canManageProject"
            v-model="editTeamId"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 font-medium focus:border-n-brand focus:outline-none w-full"
            @change="saveTeam"
          >
            <option v-for="team in teams" :key="team.id" :value="team.id">{{ formatMesaName(team.name) }}</option>
          </select>
          <span v-else class="text-sm font-medium text-n-slate-12">{{ project.team_name || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.MODULE.LABEL') }}</span>
          <span class="text-sm font-medium text-n-slate-12">{{ project.project_module_name || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak sm:col-span-2">
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

      <!-- Datas: so quem administra projetos edita; os demais so veem. -->
      <div class="grid grid-cols-2 gap-3">
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.START_DATE.LABEL') }}</span>
          <input
            v-if="canManageProject"
            v-model="editStartDate"
            type="date"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 w-full focus:border-n-brand focus:outline-none"
            @change="saveStartDate"
          />
          <span v-else class="text-sm font-medium text-n-slate-12">{{ project.start_date || '—' }}</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.DUE_DATE.LABEL') }}</span>
          <input
            v-if="canManageProject"
            v-model="editDueDate"
            type="date"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 w-full focus:border-n-brand focus:outline-none"
            @change="saveDueDate"
          />
          <span v-else class="text-sm font-medium text-n-slate-12">{{ project.due_date || '—' }}</span>
        </div>
      </div>

      <!-- Apontamento Total: soma das horas lançadas (TicketTimeEntry) em
           todos os tickets deste projeto. -->
      <div class="grid grid-cols-2 gap-3">
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.DETAIL.TOTAL_HOURS') }}</span>
          <span class="text-sm font-medium text-n-slate-12">{{ project.total_hours || 0 }}h</span>
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.DETAIL.TICKETS_STATUS') }}</span>
          <span
            class="text-sm font-medium"
            :class="project.tickets_completed ? 'text-n-teal-11' : 'text-n-amber-11'"
          >
            {{
              project.tickets_completed
                ? t('PROJECTS.DETAIL.ALL_TICKETS_DONE')
                : t('PROJECTS.DETAIL.TICKETS_PENDING')
            }}
          </span>
        </div>
      </div>

      <!-- Cancelamento: aviso + reabrir, se já cancelado; senão, o formulário
           de cancelar (some quando não está sendo usado). -->
      <div
        v-if="project.status === 'cancelled'"
        class="p-3 rounded-xl bg-n-ruby-2 border border-n-ruby-6 flex items-center justify-between gap-3"
      >
        <div>
          <span class="text-xs font-semibold text-n-ruby-11 block">{{ t('PROJECTS.DETAIL.CANCEL.CANCELLED_LABEL') }}</span>
          <span v-if="project.cancellation_reason" class="text-xs text-n-ruby-11">{{ project.cancellation_reason }}</span>
        </div>
        <NextButton
          faded
          slate
          size="sm"
          :label="t('PROJECTS.DETAIL.REACTIVATE.BUTTON')"
          @click="reactivateProject"
        />
      </div>
      <div v-else-if="showCancelForm" class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak flex flex-col gap-2">
        <label class="text-xs font-medium text-n-slate-12">{{ t('PROJECTS.DETAIL.CANCEL.REASON_LABEL') }}</label>
        <textarea
          v-model="cancelReason"
          rows="2"
          class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none resize-none"
        />
        <div class="flex justify-end gap-2">
          <NextButton faded slate size="sm" :label="t('PROJECTS.FORM.CANCEL')" @click="showCancelForm = false" />
          <NextButton ruby size="sm" :disabled="!cancelReason.trim()" :label="t('PROJECTS.DETAIL.CANCEL.CONFIRM')" @click="confirmCancel" />
        </div>
      </div>

      <!-- Implantador, datas e observação -->
      <div class="grid grid-cols-2 gap-3">
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak col-span-2">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.IMPLEMENTER.LABEL') }}</span>
          <select
            :value="project.implementer_id"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 font-medium focus:border-n-brand focus:outline-none w-full"
            @change="onImplementerChange"
          >
            <option :value="null">{{ t('PROJECTS.FORM.IMPLEMENTER.NONE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">{{ agent.name }}</option>
          </select>
        </div>
        <div v-if="project.stage === 'finalizado'" class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.COMPLETION_TYPE.LABEL') }}</span>
          <input
            v-model="completionType"
            type="text"
            :placeholder="t('PROJECTS.FORM.COMPLETION_TYPE.PLACEHOLDER')"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 w-full focus:border-n-brand focus:outline-none"
            @blur="saveCompletionType"
          />
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.CONTRACT_SIGNED_ON.LABEL') }}</span>
          <input
            v-model="contractSignedOn"
            type="date"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 w-full focus:border-n-brand focus:outline-none"
            @change="saveContractSignedOn"
          />
        </div>
        <div class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-10 block text-[11px] font-medium uppercase tracking-wide mb-1">{{ t('PROJECTS.FORM.SUPPORT_ENDS_ON.LABEL') }}</span>
          <input
            v-model="supportEndsOn"
            type="date"
            class="h-7 px-2 rounded border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 w-full focus:border-n-brand focus:outline-none"
            @change="saveSupportEndsOn"
          />
        </div>
      </div>

      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-n-slate-12">{{ t('PROJECTS.FORM.NOTES.LABEL') }}</label>
        <textarea
          v-model="notes"
          rows="2"
          :placeholder="t('PROJECTS.FORM.NOTES.PLACEHOLDER')"
          class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none resize-none"
          @blur="saveNotes"
        />
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
      <div class="flex justify-between pt-4 border-t border-n-weak">
        <NextButton
          v-if="project.status !== 'cancelled' && project.stage !== 'finalizado' && !showCancelForm"
          ruby
          faded
          type="button"
          :label="t('PROJECTS.DETAIL.CANCEL.BUTTON')"
          @click="showCancelForm = true"
        />
        <div v-else />
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
