<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import ProjectsAPI from 'dashboard/api/projects';
import ProjectModulesAPI from 'dashboard/api/projectModules';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  projectId: { type: [Number, String], required: true },
  tickets: { type: Array, default: () => [] },
  agentOptions: { type: Array, default: () => [] },
});

const emit = defineEmits(['created']);

const { t } = useI18n();

const dialogRef = ref(null);
const isSaving = ref(false);

// Cada linha vira um CalendarEvent vinculado a um ticket (existente ou
// criado na hora) - pedido da Ingrid, 2026-11-12: "vinculando tickets e
// datas a cada agendamento". `responsible_user_id` ja' vem preenchido com o
// assignee do ticket escolhido, mas pode ser trocado linha a linha.
const emptyRow = () => ({
  ticketMode: 'existing',
  ticket_id: '',
  new_ticket_title: '',
  start_at: '',
  end_at: '',
  responsible_user_id: '',
});

const rows = ref([emptyRow()]);

const ticketOptions = computed(() => props.tickets || []);

// Tickets ja' usados em alguma linha "Ticket existente" - ficam de fora do
// seletor de importacao em lote, pra nao duplicar a mesma tarefa no
// cronograma (pedido explicito: "Evitar a inclusao duplicada da mesma
// tarefa"). Linha vazia (ainda sem ticket escolhido) nao conta.
const usedTicketIds = computed(
  () =>
    new Set(
      rows.value
        .filter(row => row.ticketMode === 'existing' && row.ticket_id)
        .map(row => Number(row.ticket_id))
    )
);

const importableTickets = computed(() =>
  ticketOptions.value.filter(ticket => !usedTicketIds.value.has(ticket.id))
);

// Painel de importacao em lote ("Importar tarefas" / "Importar modulo") -
// pedido da Ingrid, 2026-11-14: evitar ter que adicionar tarefa por tarefa
// manualmente. Os dois botoes abrem o MESMO painel de selecao multipla; a
// diferenca e' so' que "Importar modulo" pre-marca as tarefas daquele
// modulo em vez de deixar tudo desmarcado.
const showImportPanel = ref(false);
const selectedImportIds = ref([]);
const projectModules = ref([]);
const isLoadingModules = ref(false);
const selectedModuleId = ref('');

const openImportPanel = async () => {
  showImportPanel.value = true;
  selectedImportIds.value = [];
  selectedModuleId.value = '';
  if (projectModules.value.length) return;

  isLoadingModules.value = true;
  try {
    const { data } = await ProjectModulesAPI.get();
    projectModules.value = data || [];
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.SCHEDULE.IMPORT.MODULES_ERROR'));
  } finally {
    isLoadingModules.value = false;
  }
};

const closeImportPanel = () => {
  showImportPanel.value = false;
};

// Tarefas deste projeto cujo modelo pertence ao modulo escolhido - so'
// filtra o que ja' existe no projeto (nunca cria ticket novo aqui, pedido
// explicito: "Manter o vinculo com as tarefas originais, sem criar novos
// tickets desnecessariamente").
const moduleTaskTemplateIds = computed(() => {
  const selected = projectModules.value.find(
    projectModule => projectModule.id === Number(selectedModuleId.value)
  );
  return new Set((selected?.task_templates || []).map(template => template.id));
});

const onModuleSelect = () => {
  if (!selectedModuleId.value) {
    selectedImportIds.value = [];
    return;
  }
  selectedImportIds.value = importableTickets.value
    .filter(ticket => moduleTaskTemplateIds.value.has(ticket.project_task_template_id))
    .map(ticket => ticket.id);
};

// Tira a linha em branco inicial do caminho, pra nao sobrar um cartao vazio
// junto das tarefas importadas.
const isPristineRow = row =>
  row.ticketMode === 'existing' && !row.ticket_id && !row.new_ticket_title && !row.start_at;

const confirmImport = () => {
  if (!selectedImportIds.value.length) {
    closeImportPanel();
    return;
  }
  if (rows.value.length === 1 && isPristineRow(rows.value[0])) {
    rows.value = [];
  }
  selectedImportIds.value.forEach(ticketId => {
    const ticket = importableTickets.value.find(candidate => candidate.id === ticketId);
    if (!ticket) return;
    rows.value.push({
      ...emptyRow(),
      ticket_id: ticket.id,
      responsible_user_id: ticket.assignee_id || '',
    });
  });
  closeImportPanel();
};

const open = () => {
  rows.value = [emptyRow()];
  showImportPanel.value = false;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const addRow = () => rows.value.push(emptyRow());
const removeRow = index => rows.value.splice(index, 1);

const onTicketSelect = row => {
  const ticket = ticketOptions.value.find(t2 => t2.id === Number(row.ticket_id));
  row.responsible_user_id = ticket?.assignee_id || '';
};

const isRowValid = row => {
  const hasTicket = row.ticketMode === 'existing' ? !!row.ticket_id : !!row.new_ticket_title.trim();
  return hasTicket && !!row.start_at;
};

const canSave = computed(() => rows.value.some(isRowValid));

const buildItems = () =>
  rows.value.filter(isRowValid).map(row => ({
    ticket_id: row.ticketMode === 'existing' ? row.ticket_id : undefined,
    new_ticket_title: row.ticketMode === 'new' ? row.new_ticket_title.trim() : undefined,
    start_at: row.start_at,
    end_at: row.end_at || undefined,
    responsible_user_id: row.responsible_user_id || undefined,
  }));

// O backend isola cada linha (uma com problema nao derruba as outras), entao
// a resposta sempre separa o que deu certo (`created_count`) do que falhou
// (`failed`, com o motivo de cada um) - pedido da Ingrid, 2026-11-13: parar
// de mostrar "Internal Server Error" sem explicacao nenhuma.
const save = async () => {
  const items = buildItems();
  if (!items.length) return;

  isSaving.value = true;
  try {
    const { data } = await ProjectsAPI.createSchedule(props.projectId, items);

    if (data.failed?.length) {
      const failedSummary = data.failed
        .map(item => `"${item.label}": ${item.error}`)
        .join(' | ');
      useAlert(
        t('PROJECTS.SCHEDULE.PARTIAL_FAILURE', {
          createdCount: data.created_count,
          totalCount: data.created_count + data.failed.length,
          failedSummary,
        })
      );
    } else {
      useAlert(t('PROJECTS.SCHEDULE.SUCCESS', { count: data.created_count }));
    }

    if (data.created_count > 0) {
      emit('created');
      close();
    }
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.SCHEDULE.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('PROJECTS.SCHEDULE.TITLE')"
    :description="t('PROJECTS.SCHEDULE.DESCRIPTION')"
    width="2xl"
    overflow-y-auto
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="flex flex-col gap-3 max-h-[55vh] overflow-y-auto">
      <div
        v-for="(row, index) in rows"
        :key="index"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak bg-n-alpha-1"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-1 p-0.5 rounded-lg bg-n-slate-3 w-fit">
            <button
              type="button"
              class="px-2 py-1 text-xs rounded-md"
              :class="row.ticketMode === 'existing' ? 'bg-n-solid-1 text-n-slate-12' : 'text-n-slate-11'"
              @click="row.ticketMode = 'existing'"
            >
              {{ t('PROJECTS.SCHEDULE.EXISTING_TICKET') }}
            </button>
            <button
              type="button"
              class="px-2 py-1 text-xs rounded-md"
              :class="row.ticketMode === 'new' ? 'bg-n-solid-1 text-n-slate-12' : 'text-n-slate-11'"
              @click="row.ticketMode = 'new'"
            >
              {{ t('PROJECTS.SCHEDULE.NEW_TICKET') }}
            </button>
          </div>
          <button
            v-if="rows.length > 1"
            type="button"
            :aria-label="t('PROJECTS.SCHEDULE.REMOVE_ROW')"
            class="text-n-slate-10 hover:text-n-ruby-11"
            @click="removeRow(index)"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </div>

        <select
          v-if="row.ticketMode === 'existing'"
          v-model="row.ticket_id"
          class="h-9 w-full text-sm"
          @change="onTicketSelect(row)"
        >
          <option value="">{{ t('PROJECTS.SCHEDULE.SELECT_TICKET') }}</option>
          <option v-for="ticket in ticketOptions" :key="ticket.id" :value="ticket.id">
            #{{ ticket.display_id || ticket.id }} - {{ ticket.title }}
          </option>
        </select>
        <input
          v-else
          v-model="row.new_ticket_title"
          type="text"
          :placeholder="t('PROJECTS.SCHEDULE.NEW_TICKET_PLACEHOLDER')"
          class="h-9 w-full text-sm"
        />

        <div class="grid grid-cols-3 gap-2">
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.START_AT') }}
            <input v-model="row.start_at" type="datetime-local" class="h-9 w-full text-xs" />
          </label>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.END_AT') }}
            <input v-model="row.end_at" type="datetime-local" class="h-9 w-full text-xs" />
          </label>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.RESPONSIBLE') }}
            <select v-model="row.responsible_user_id" class="h-9 w-full text-xs">
              <option value="">{{ t('PROJECTS.SCHEDULE.NO_RESPONSIBLE') }}</option>
              <option v-for="agent in agentOptions" :key="agent.value" :value="agent.value">
                {{ agent.label }}
              </option>
            </select>
          </label>
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        <NextButton
          icon="i-lucide-plus"
          size="sm"
          faded
          slate
          :label="t('PROJECTS.SCHEDULE.ADD_ROW')"
          @click="addRow"
        />
        <NextButton
          icon="i-lucide-list-checks"
          size="sm"
          faded
          slate
          :label="t('PROJECTS.SCHEDULE.IMPORT.BUTTON')"
          @click="openImportPanel"
        />
      </div>

      <!-- Importar tarefas / modulo - um unico painel de selecao multipla;
           escolher um modulo so' pre-marca as tarefas dele, nunca cria
           ticket novo (pedido: so' vincula o que ja' existe no projeto). -->
      <div
        v-if="showImportPanel"
        class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak bg-n-alpha-1"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.SCHEDULE.IMPORT.TITLE') }}
          </span>
          <button
            type="button"
            :aria-label="t('PROJECTS.SCHEDULE.REMOVE_ROW')"
            class="text-n-slate-10 hover:text-n-ruby-11"
            @click="closeImportPanel"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </div>

        <label class="flex flex-col gap-1 text-xs text-n-slate-11">
          {{ t('PROJECTS.SCHEDULE.IMPORT.MODULE_LABEL') }}
          <select
            v-model="selectedModuleId"
            class="h-9 w-full text-sm"
            :disabled="isLoadingModules"
            @change="onModuleSelect"
          >
            <option value="">{{ t('PROJECTS.SCHEDULE.IMPORT.MODULE_PLACEHOLDER') }}</option>
            <option
              v-for="projectModule in projectModules"
              :key="projectModule.id"
              :value="projectModule.id"
            >
              {{ projectModule.name }}
            </option>
          </select>
        </label>

        <div v-if="isLoadingModules" class="text-xs text-n-slate-10">
          {{ t('PROJECTS.SCHEDULE.IMPORT.LOADING') }}
        </div>
        <div
          v-else-if="!importableTickets.length"
          class="text-xs text-n-slate-10"
        >
          {{ t('PROJECTS.SCHEDULE.IMPORT.NO_TICKETS') }}
        </div>
        <div v-else class="flex flex-col gap-1 overflow-y-auto max-h-48">
          <label
            v-for="ticket in importableTickets"
            :key="ticket.id"
            class="flex items-center gap-2 px-2 py-1.5 text-sm rounded-md cursor-pointer hover:bg-n-alpha-2 text-n-slate-12"
          >
            <input
              v-model="selectedImportIds"
              type="checkbox"
              :value="ticket.id"
              class="shrink-0"
            />
            <span class="truncate">#{{ ticket.display_id || ticket.id }} - {{ ticket.title }}</span>
          </label>
        </div>

        <div class="flex items-center justify-between">
          <span class="text-xs text-n-slate-10">
            {{ t('PROJECTS.SCHEDULE.IMPORT.SELECTED_COUNT', { count: selectedImportIds.length }) }}
          </span>
          <NextButton
            size="sm"
            :label="t('PROJECTS.SCHEDULE.IMPORT.CONFIRM')"
            :disabled="!selectedImportIds.length"
            @click="confirmImport"
          />
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <NextButton
          variant="faded"
          color="slate"
          type="button"
          class="w-full"
          :label="t('PROJECTS.FORM.CANCEL')"
          @click="close"
        />
        <NextButton
          type="button"
          class="w-full"
          :label="t('PROJECTS.SCHEDULE.SAVE')"
          :is-loading="isSaving"
          :disabled="!canSave || isSaving"
          @click="save"
        />
      </div>
    </template>
  </Dialog>
</template>
