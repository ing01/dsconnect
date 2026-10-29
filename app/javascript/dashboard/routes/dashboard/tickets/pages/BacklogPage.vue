<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ConfirmButton from 'dashboard/components-next/button/ConfirmButton.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketMesaSelector from '../components/TicketMesaSelector.vue';
import TicketAvatarFilterRow from '../components/TicketAvatarFilterRow.vue';
import TicketSelect from '../components/TicketSelect.vue';
import TicketBoard from '../components/TicketBoard.vue';
import TicketCreateDialog from '../components/create/TicketCreateDialog.vue';
import BacklogBucket from '../components/backlog/BacklogBucket.vue';
import BacklogBulkActionsBar from '../components/backlog/BacklogBulkActionsBar.vue';
import BacklogBulkEditDialog from '../components/backlog/BacklogBulkEditDialog.vue';
import { useBacklog } from '../composables/useBacklog';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const {
  devTeams,
  sprints,
  board,
  mesaAgents,
  columns,
  state,
  selectTeam,
  selectBoardSprint,
  createSprint,
  moveTicketToSprint,
  moveTicketToColumn,
  moveTicketInBoard,
  concludeSprint,
  ensureBoardLoaded,
  bulkUpdateTickets,
  bulkMoveToColumn,
  reload,
} = useBacklog();

// Selecao para a edicao em massa - uma lista so', compartilhada entre todos
// os baldes do Backlog (Sprints + o proprio Backlog), igual a segunda
// imagem de referencia mostra (selecao atravessa os blocos).
const selectedTicketIds = ref([]);
const clearSelection = () => {
  selectedTicketIds.value = [];
};
const toggleSelect = ticketId => {
  selectedTicketIds.value = selectedTicketIds.value.includes(ticketId)
    ? selectedTicketIds.value.filter(id => id !== ticketId)
    : [...selectedTicketIds.value, ticketId];
};
const selectMany = (ticketIds, shouldSelect) => {
  const withoutThese = selectedTicketIds.value.filter(
    id => !ticketIds.includes(id)
  );
  selectedTicketIds.value = shouldSelect
    ? [...withoutThese, ...ticketIds]
    : withoutThese;
};

// Os proprios tickets selecionados (nao so' os ids) - pra listar o numero de
// cada um no modal. Procura nos baldes que ja estao carregados: Sprints +
// Backlog, os mesmos dados que as linhas ja mostram.
const allLoadedTickets = computed(() => [
  ...Object.values(state.ticketsBySprint).flat(),
  ...state.backlogTickets,
]);
const selectedTickets = computed(() =>
  allLoadedTickets.value.filter(ticket =>
    selectedTicketIds.value.includes(ticket.id)
  )
);

const bulkEditDialogRef = ref(null);
const openBulkEditDialog = () => bulkEditDialogRef.value?.open();

const isBulkSubmitting = ref(false);

// So' manda pro servidor o que de fato mudou no modal - "Manter como está"
// em cada campo ja chega como `undefined` daqui (ver BacklogBulkEditDialog).
const onBulkEditConfirm = async ({
  columnId,
  sprintId,
  priority,
  assigneeId,
}) => {
  isBulkSubmitting.value = true;
  try {
    const patch = {};
    if (sprintId !== undefined) patch.sprint_id = sprintId;
    if (priority !== undefined) patch.priority = priority;
    if (assigneeId !== undefined) patch.assignee_id = assigneeId;

    if (Object.keys(patch).length) {
      await bulkUpdateTickets(selectedTicketIds.value, patch);
    }
    if (columnId !== undefined) {
      await bulkMoveToColumn(selectedTicketIds.value, columnId);
    }

    bulkEditDialogRef.value?.close();
    clearSelection();
  } finally {
    isBulkSubmitting.value = false;
  }
};

// Filtros do Backlog/Sprint ativo - puramente visuais (ver
// `ticketMatchesFilters`), aplicados aos dois do mesmo jeito.
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
const filters = ref({
  query: '',
  assigneeIds: [],
  priority: '',
  columnId: null,
});

const priorityOptions = computed(() =>
  PRIORITIES.map(value => ({
    value,
    label: t(`TICKET.FORM.PRIORITY.${value.toUpperCase()}`),
  }))
);

const columnOptions = computed(() =>
  columns.value.map(column => ({ value: column.id, label: column.name }))
);

// "Backlog": a lista por Sprint, com arrastar-e-soltar entre eles.
// "board": o mesmo Kanban da Mesa, so' mostrando o Sprint escolhido - onde
// se trabalha dentro de um Sprint e se Concluir ele.
const viewMode = ref('backlog');

// Cada aba busca os PROPRIOS dados de novo ao ser aberta - sem isso, um
// ticket que entrou numa Sprint por outro caminho (ex.: pela tela de
// detalhe, enquanto se estava no Sprint ativo) so' aparecia no Backlog depois
// de recarregar a pagina inteira, porque a lista de cada balde era buscada
// so' uma vez, na primeira troca de Mesa.
watch(viewMode, mode => {
  clearSelection();
  if (mode === 'board') {
    ensureBoardLoaded();
  } else {
    reload();
  }
});

// Trocar de Mesa enquanto na aba "Sprint ativo" tambem precisa buscar o
// quadro da Mesa nova - o Backlog ja se recarrega sozinho nesse caso (ver
// `watch(selectedTeamId, loadTeamData)` dentro do composable).
watch(
  () => state.selectedTeamId,
  () => {
    clearSelection();
    if (viewMode.value === 'board') ensureBoardLoaded();
  }
);

const sortedSprints = computed(() =>
  [...sprints.value].sort((a, b) => a.starts_on.localeCompare(b.starts_on))
);

const sprintSubtitle = sprint => `${sprint.starts_on} - ${sprint.ends_on}`;

const openTicket = ticket => {
  router.push(
    frontendURL(`accounts/${route.params.accountId}/tickets/${ticket.id}`)
  );
};

const showSprintForm = ref(false);
const newSprint = ref({ name: '', startsOn: '', endsOn: '' });

const canCreateSprint = computed(
  () =>
    newSprint.value.name.trim() &&
    newSprint.value.startsOn &&
    newSprint.value.endsOn
);

const submitSprint = async () => {
  if (!canCreateSprint.value) return;
  await createSprint(newSprint.value);
  newSprint.value = { name: '', startsOn: '', endsOn: '' };
  showSprintForm.value = false;
};

const boardSprint = computed(() =>
  sprints.value.find(sprint => sprint.id === state.boardSprintId)
);

const boardFilters = computed(() => ({
  ...filters.value,
  sprintId: state.boardSprintId,
}));

// Abrir ticket direto de dentro de um Estagio do Sprint ativo - o mesmo
// formulario de criacao do Kanban, so' que com o Sprint ja' preenchido.
const showTicketCreateForm = ref(false);
const targetColumnId = ref(null);
const onAddTicket = column => {
  targetColumnId.value = column.id;
  showTicketCreateForm.value = true;
};
const closeTicketCreateForm = () => {
  showTicketCreateForm.value = false;
  targetColumnId.value = null;
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 overflow-y-auto p-4 gap-4">
    <div class="flex items-center flex-wrap gap-2">
      <h1 class="text-lg font-medium text-n-slate-12 m-0">
        {{ t('TICKET.BACKLOG.TITLE') }}
      </h1>
      <TicketMesaSelector
        :teams="devTeams"
        :selected-team-id="state.selectedTeamId"
        @select="selectTeam"
      />

      <div
        v-if="state.selectedTeamId"
        class="flex items-center gap-1 rounded-lg border border-n-weak p-0.5"
      >
        <button
          type="button"
          class="h-7 px-2.5 text-sm rounded-md"
          :class="
            viewMode === 'backlog'
              ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
              : 'text-n-slate-11'
          "
          @click="viewMode = 'backlog'"
        >
          {{ t('TICKET.BACKLOG.VIEW_BACKLOG') }}
        </button>
        <button
          type="button"
          class="h-7 px-2.5 text-sm rounded-md"
          :class="
            viewMode === 'board'
              ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
              : 'text-n-slate-11'
          "
          @click="viewMode = 'board'"
        >
          {{ t('TICKET.BACKLOG.VIEW_BOARD') }}
        </button>
      </div>

      <NextButton
        v-if="state.selectedTeamId && viewMode === 'backlog'"
        size="sm"
        icon="i-lucide-plus"
        :label="t('TICKET.BACKLOG.CREATE_SPRINT')"
        class="ltr:ml-auto rtl:mr-auto"
        @click="showSprintForm = !showSprintForm"
      />

      <template v-if="state.selectedTeamId && viewMode === 'board'">
        <select
          :value="state.boardSprintId"
          class="mb-0 h-8 ltr:ml-auto rtl:mr-auto"
          @change="selectBoardSprint($event.target.value)"
        >
          <option
            v-for="sprint in sortedSprints"
            :key="sprint.id"
            :value="sprint.id"
          >
            {{ sprint.name }}
          </option>
        </select>
        <ConfirmButton
          v-if="boardSprint"
          size="sm"
          color="slate"
          confirm-color="ruby"
          :label="t('TICKET.BACKLOG.CONCLUDE_SPRINT')"
          :confirm-label="t('TICKET.BACKLOG.CONCLUDE_SPRINT_CONFIRM')"
          @click="concludeSprint(boardSprint.id)"
        />
      </template>
    </div>

    <p v-if="!devTeams.length" class="text-sm text-n-slate-10">
      {{ t('TICKET.BACKLOG.NO_DEV_MESA') }}
    </p>

    <form
      v-if="showSprintForm"
      class="flex flex-wrap items-end gap-2 rounded-lg border border-n-weak p-3"
      @submit.prevent="submitSprint"
    >
      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-10">
          {{ t('TICKET.BACKLOG.SPRINT_NAME') }}
        </span>
        <input
          v-model="newSprint.name"
          type="text"
          class="mb-0 h-9"
          :placeholder="t('TICKET.BACKLOG.SPRINT_NAME_PLACEHOLDER')"
        />
      </label>
      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-10">
          {{ t('TICKET.BACKLOG.SPRINT_STARTS_ON') }}
        </span>
        <input v-model="newSprint.startsOn" type="date" class="mb-0 h-9" />
      </label>
      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-10">
          {{ t('TICKET.BACKLOG.SPRINT_ENDS_ON') }}
        </span>
        <input v-model="newSprint.endsOn" type="date" class="mb-0 h-9" />
      </label>
      <NextButton
        type="submit"
        size="sm"
        :disabled="!canCreateSprint"
        :is-loading="state.isCreatingSprint"
        :label="t('TICKET.BACKLOG.SAVE_SPRINT')"
      />
    </form>

    <div
      v-if="state.selectedTeamId"
      class="flex items-center flex-wrap gap-2 rounded-lg border border-n-weak p-2"
    >
      <input
        v-model="filters.query"
        type="text"
        class="mb-0 h-8 w-48"
        :placeholder="t('TICKET.BACKLOG.FILTER_SEARCH_PLACEHOLDER')"
      />
      <TicketAvatarFilterRow
        :agents="mesaAgents"
        :selected-agent-ids="filters.assigneeIds"
        @select="ids => (filters.assigneeIds = ids)"
      />
      <TicketSelect
        v-model="filters.priority"
        :options="priorityOptions"
        clearable
        :clear-label="t('TICKET.BACKLOG.FILTER_ALL_PRIORITIES')"
        :placeholder="t('TICKET.BACKLOG.FILTER_ALL_PRIORITIES')"
        :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
        class="w-40"
      />
      <TicketSelect
        v-model="filters.columnId"
        :options="columnOptions"
        clearable
        :clear-label="t('TICKET.BACKLOG.FILTER_ALL_STAGES')"
        :placeholder="t('TICKET.BACKLOG.FILTER_ALL_STAGES')"
        :aria-label="t('TICKET.DETAIL.PROPERTIES.STAGE')"
        class="w-44"
      />
    </div>

    <Spinner v-if="state.isLoading" />

    <template v-if="state.selectedTeamId && !state.isLoading">
      <template v-if="viewMode === 'backlog'">
        <BacklogBucket
          v-for="sprint in sortedSprints"
          :key="sprint.id"
          :title="sprint.name"
          :subtitle="sprintSubtitle(sprint)"
          :tickets="state.ticketsBySprint[sprint.id] || []"
          :agents="mesaAgents"
          :columns="columns"
          :filters="filters"
          :selected-ids="selectedTicketIds"
          @open-ticket="openTicket"
          @move-ticket="ticketId => moveTicketToSprint(ticketId, sprint.id)"
          @move-to-column="moveTicketToColumn"
          @toggle-select="toggleSelect"
          @select-many="selectMany"
        />

        <BacklogBucket
          :title="t('TICKET.BACKLOG.BACKLOG_BUCKET')"
          :tickets="state.backlogTickets"
          :agents="mesaAgents"
          :columns="columns"
          :filters="filters"
          :selected-ids="selectedTicketIds"
          @open-ticket="openTicket"
          @move-ticket="ticketId => moveTicketToSprint(ticketId, null)"
          @move-to-column="moveTicketToColumn"
          @toggle-select="toggleSelect"
          @select-many="selectMany"
        />
      </template>

      <!-- Altura de quase a tela toda, em vez do que sobra depois do cabecalho e
           dos filtros (`flex-1 min-h-0` deixava as colunas com ~300px): a PAGINA
           rola ate o quadro, e as colunas rolam por dentro. A margem cobre a
           barra de abas e o respiro da pagina. -->
      <div v-else class="flex-shrink-0 min-w-0 h-[calc(100vh-9rem)] min-h-[28rem]">
        <p
          v-if="!board || !state.boardSprintId"
          class="text-sm text-n-slate-10"
        >
          {{ t('TICKET.BACKLOG.NO_SPRINT_SELECTED') }}
        </p>
        <TicketBoard
          v-else
          :board="board"
          :account-id="route.params.accountId"
          :team-id="state.selectedTeamId"
          :agents="mesaAgents"
          :filters="boardFilters"
          @add-ticket="onAddTicket"
          @open-ticket="openTicket"
          @move-ticket="moveTicketInBoard"
        />
      </div>
    </template>

    <woot-modal
      v-model:show="showTicketCreateForm"
      :on-close="closeTicketCreateForm"
      size="large"
    >
      <TicketCreateDialog
        :context="{
          teamId: state.selectedTeamId,
          ticketColumnId: targetColumnId,
          sprintId: boardSprint?.id,
        }"
        @close="closeTicketCreateForm"
        @created="closeTicketCreateForm"
      />
    </woot-modal>

    <BacklogBulkActionsBar
      v-if="viewMode === 'backlog'"
      :selected-count="selectedTicketIds.length"
      @clear="clearSelection"
      @edit-fields="openBulkEditDialog"
    />

    <BacklogBulkEditDialog
      ref="bulkEditDialogRef"
      :tickets="selectedTickets"
      :columns="columns"
      :sprints="sortedSprints"
      :agents="mesaAgents"
      :is-submitting="isBulkSubmitting"
      @confirm="onBulkEditConfirm"
    />
  </div>
</template>
