<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import ProjectsAPI from 'dashboard/api/projects';
import ProjectModulesAPI from 'dashboard/api/projectModules';
import ProjectTaskTemplatesAPI from 'dashboard/api/projectTaskTemplates';
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
  new_ticket_description: '',
  start_at: '',
  end_at: '',
  responsible_user_id: '',
  // So preenchido quando a linha nasceu da importacao de um Modelo de Tarefa
  // (ver `confirmImport`) - usado so' pra nao deixar importar o mesmo modelo
  // duas vezes, nunca enviado pro backend.
  source_template_id: null,
});

const rows = ref([emptyRow()]);

const ticketOptions = computed(() => props.tickets || []);

// Painel de importacao em lote ("Importar tarefas") - pedido da Ingrid,
// 2026-11-14: evitar ter que adicionar tarefa por tarefa manualmente.
//
// 2026-11-24: a lista mostrava so' os tickets JA' criados neste projeto, o
// que escondia Modelos de Tarefa de modulos que nunca foram gerados aqui.
// Agora mostra TODO o catalogo de Modelos de Tarefa (de todos os modulos),
// com o nome do modulo de origem embaixo - o dropdown so' filtra essa lista,
// nao pre-marca nada. Pra nao duplicar tarefa: se o modelo escolhido ja' bate
// com um ticket existente no projeto (`project_task_template_id`), a linha
// importada vincula a ESSE ticket; so' cria ticket novo quando o projeto
// ainda nao tem um ticket gerado daquele modelo.
const showImportPanel = ref(false);
const selectedImportIds = ref([]);
const projectModules = ref([]);
const templateCatalog = ref([]);
const isLoadingImportPanel = ref(false);
const selectedModuleId = ref('');

const openImportPanel = async () => {
  showImportPanel.value = true;
  selectedImportIds.value = [];
  selectedModuleId.value = '';
  if (projectModules.value.length && templateCatalog.value.length) return;

  isLoadingImportPanel.value = true;
  try {
    const [{ data: modules }, { data: templates }] = await Promise.all([
      ProjectModulesAPI.get(),
      ProjectTaskTemplatesAPI.get(),
    ]);
    projectModules.value = modules || [];
    templateCatalog.value = templates || [];
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t('PROJECTS.SCHEDULE.IMPORT.MODULES_ERROR')
    );
  } finally {
    isLoadingImportPanel.value = false;
  }
};

const closeImportPanel = () => {
  showImportPanel.value = false;
};

// Chave que identifica, pra fins de "ja' usado", o resultado de importar um
// modelo: o ticket que ele vai acabar vinculando (existente) ou o proprio
// modelo (quando a importacao vai criar um ticket novo a partir dele).
const rowImportKey = row => {
  if (row.ticketMode === 'existing' && row.ticket_id)
    return `ticket-${row.ticket_id}`;
  if (row.ticketMode === 'new' && row.source_template_id)
    return `template-${row.source_template_id}`;
  return null;
};

const usedImportKeys = computed(
  () => new Set(rows.value.map(rowImportKey).filter(Boolean))
);

// Cada modelo do catalogo junto do ticket deste projeto que ja' foi gerado a
// partir dele (se houver) - e' o que decide, na importacao, se a linha vai
// vincular esse ticket ou criar um novo.
const importableTemplates = computed(() =>
  templateCatalog.value
    .filter(
      template =>
        !selectedModuleId.value ||
        (template.project_modules || []).some(
          projectModule => projectModule.id === Number(selectedModuleId.value)
        )
    )
    .map(template => ({
      template,
      matchedTicket: ticketOptions.value.find(
        ticket => ticket.project_task_template_id === template.id
      ),
    }))
    .filter(({ template, matchedTicket }) => {
      const key = matchedTicket
        ? `ticket-${matchedTicket.id}`
        : `template-${template.id}`;
      return !usedImportKeys.value.has(key);
    })
);

const moduleNamesLabel = template =>
  (template.project_modules || [])
    .map(projectModule => projectModule.name)
    .join(', ') || t('PROJECTS.SCHEDULE.IMPORT.NO_MODULE');

// Tira a linha em branco inicial do caminho, pra nao sobrar um cartao vazio
// junto das tarefas importadas.
const isPristineRow = row =>
  row.ticketMode === 'existing' &&
  !row.ticket_id &&
  !row.new_ticket_title &&
  !row.start_at;

const confirmImport = () => {
  if (!selectedImportIds.value.length) {
    closeImportPanel();
    return;
  }
  if (rows.value.length === 1 && isPristineRow(rows.value[0])) {
    rows.value = [];
  }
  selectedImportIds.value.forEach(templateId => {
    const entry = importableTemplates.value.find(
      candidate => candidate.template.id === templateId
    );
    if (!entry) return;
    const { template, matchedTicket } = entry;

    if (matchedTicket) {
      rows.value.push({
        ...emptyRow(),
        ticketMode: 'existing',
        ticket_id: matchedTicket.id,
        responsible_user_id:
          matchedTicket.assignee_id || template.default_assignee_id || '',
      });
    } else {
      rows.value.push({
        ...emptyRow(),
        ticketMode: 'new',
        source_template_id: template.id,
        new_ticket_title: template.default_ticket_title || template.name,
        new_ticket_description: template.description || '',
        responsible_user_id: template.default_assignee_id || '',
      });
    }
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
  const ticket = ticketOptions.value.find(
    t2 => t2.id === Number(row.ticket_id)
  );
  row.responsible_user_id = ticket?.assignee_id || '';
};

const isRowValid = row => {
  // Ticket novo precisa de título e descrição (o ticket exige os dois).
  const hasTicket =
    row.ticketMode === 'existing'
      ? !!row.ticket_id
      : !!row.new_ticket_title.trim() && !!row.new_ticket_description.trim();
  return hasTicket && !!row.start_at;
};

const canSave = computed(() => rows.value.some(isRowValid));

const buildItems = () =>
  rows.value.filter(isRowValid).map(row => ({
    ticket_id: row.ticketMode === 'existing' ? row.ticket_id : undefined,
    new_ticket_title:
      row.ticketMode === 'new' ? row.new_ticket_title.trim() : undefined,
    description:
      row.ticketMode === 'new' ? row.new_ticket_description.trim() : undefined,
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
          <div
            class="flex items-center gap-1 p-0.5 rounded-lg bg-n-slate-3 w-fit"
          >
            <button
              type="button"
              class="px-2 py-1 text-xs rounded-md"
              :class="
                row.ticketMode === 'existing'
                  ? 'bg-n-solid-1 text-n-slate-12'
                  : 'text-n-slate-11'
              "
              @click="row.ticketMode = 'existing'"
            >
              {{ t('PROJECTS.SCHEDULE.EXISTING_TICKET') }}
            </button>
            <button
              type="button"
              class="px-2 py-1 text-xs rounded-md"
              :class="
                row.ticketMode === 'new'
                  ? 'bg-n-solid-1 text-n-slate-12'
                  : 'text-n-slate-11'
              "
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
          <option
            v-for="ticket in ticketOptions"
            :key="ticket.id"
            :value="ticket.id"
          >
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
        <textarea
          v-if="row.ticketMode === 'new'"
          v-model="row.new_ticket_description"
          rows="3"
          :placeholder="
            t('PROJECTS.SCHEDULE.NEW_TICKET_DESCRIPTION_PLACEHOLDER')
          "
          class="w-full text-sm"
          data-testid="new-ticket-description"
        />

        <div class="grid grid-cols-3 gap-2">
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.START_AT') }}
            <input
              v-model="row.start_at"
              type="datetime-local"
              class="h-9 w-full text-xs"
            />
          </label>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.END_AT') }}
            <input
              v-model="row.end_at"
              type="datetime-local"
              class="h-9 w-full text-xs"
            />
          </label>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.RESPONSIBLE') }}
            <select
              v-model="row.responsible_user_id"
              class="h-9 w-full text-xs"
            >
              <option value="">
                {{ t('PROJECTS.SCHEDULE.NO_RESPONSIBLE') }}
              </option>
              <option
                v-for="agent in agentOptions"
                :key="agent.value"
                :value="agent.value"
              >
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

      <!-- Importar tarefas - lista TODO o catalogo de Modelos de Tarefa (de
           todos os modulos); o dropdown so' filtra a lista pelo modulo
           escolhido. Cada item mostra de qual modulo ele vem, e se vai
           vincular um ticket ja' existente no projeto ou criar um novo. -->
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
            :disabled="isLoadingImportPanel"
          >
            <option value="">
              {{ t('PROJECTS.SCHEDULE.IMPORT.MODULE_PLACEHOLDER') }}
            </option>
            <option
              v-for="projectModule in projectModules"
              :key="projectModule.id"
              :value="projectModule.id"
            >
              {{ projectModule.name }}
            </option>
          </select>
        </label>

        <div v-if="isLoadingImportPanel" class="text-xs text-n-slate-10">
          {{ t('PROJECTS.SCHEDULE.IMPORT.LOADING') }}
        </div>
        <div
          v-else-if="!importableTemplates.length"
          class="text-xs text-n-slate-10"
        >
          {{ t('PROJECTS.SCHEDULE.IMPORT.NO_TICKETS') }}
        </div>
        <div v-else class="flex flex-col gap-1 overflow-y-auto max-h-48">
          <label
            v-for="{ template, matchedTicket } in importableTemplates"
            :key="template.id"
            class="flex items-center gap-2 px-2 py-1.5 text-sm rounded-md cursor-pointer hover:bg-n-alpha-2 text-n-slate-12"
          >
            <input
              v-model="selectedImportIds"
              type="checkbox"
              :value="template.id"
              class="shrink-0"
            />
            <span class="flex flex-col min-w-0 truncate">
              <span class="truncate">{{ template.name }}</span>
              <span class="text-xs text-n-slate-10 truncate">
                - {{ moduleNamesLabel(template) }}
                ·
                {{
                  matchedTicket
                    ? t('PROJECTS.SCHEDULE.IMPORT.LINKS_EXISTING_TICKET', {
                        displayId: matchedTicket.display_id || matchedTicket.id,
                      })
                    : t('PROJECTS.SCHEDULE.IMPORT.CREATES_NEW_TICKET')
                }}
              </span>
            </span>
          </label>
        </div>

        <div class="flex items-center justify-between">
          <span class="text-xs text-n-slate-10">
            {{
              t('PROJECTS.SCHEDULE.IMPORT.SELECTED_COUNT', {
                count: selectedImportIds.length,
              })
            }}
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
