<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SuggestionBoard from '../components/SuggestionBoard.vue';
import SuggestionDetailDialog from '../components/SuggestionDetailDialog.vue';
import SuggestionCreateDialog from '../components/SuggestionCreateDialog.vue';
import { suggestionMatchesFilters } from '../helpers/suggestionFilters';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { checkPermissions } = usePolicy();

const canManage = computed(() =>
  checkPermissions(['administrator', 'suggestion_manage'])
);
// Titulo/descricao originais so' Administrador corrige - `suggestion_manage`
// sozinho nao basta (mesma regra do backend).
const isAdmin = computed(() => checkPermissions(['administrator']));

const columns = computed(() => store.getters['suggestionColumns/getColumns']);
const suggestions = computed(() => store.getters['suggestions/getSuggestions']);
const uiFlags = computed(() => store.getters['suggestions/getUIFlags']);

const priorities = computed(
  () => store.getters['suggestionPriorities/getItems']
);
const categories = computed(
  () => store.getters['suggestionCategories/getItems']
);
// So' Administradores podem ser Responsavel - mesma lista usada no dialogo
// de detalhe, aqui pra popular o filtro.
const administrators = computed(() =>
  (store.getters['agents/getAgents'] || []).filter(
    agent => agent.role === 'administrator'
  )
);

const filters = ref({
  priorityId: '',
  categoryId: '',
  assigneeId: '',
  dateFrom: '',
  dateTo: '',
});

const hasActiveFilters = computed(() =>
  Object.values(filters.value).some(value => value)
);

const filteredSuggestions = computed(() =>
  suggestions.value.filter(suggestion =>
    suggestionMatchesFilters(suggestion, filters.value)
  )
);

const clearFilters = () => {
  filters.value = {
    priorityId: '',
    categoryId: '',
    assigneeId: '',
    dateFrom: '',
    dateTo: '',
  };
};

const detailDialog = ref(null);
const createDialog = ref(null);
const isCreating = ref(false);

const loadBoard = () => {
  store.dispatch('suggestionColumns/get');
  store.dispatch('suggestionPriorities/get');
  store.dispatch('suggestionCategories/get');
  store.dispatch('agents/get');
  store.dispatch('suggestions/get');
};

onMounted(loadBoard);

const openSuggestion = suggestion => detailDialog.value?.open(suggestion);

const openCreateDialog = () => createDialog.value?.open();

const createSuggestion = async ({
  title,
  description,
  assigneeId,
  priorityId,
  categoryId,
  timeSpentHours,
  files,
}) => {
  isCreating.value = true;
  try {
    await store.dispatch('suggestions/create', {
      title,
      description,
      assigneeId,
      priorityId,
      categoryId,
      timeSpentHours,
      files,
    });
    createDialog.value?.close();
    useAlert(t('SUGGESTIONS.CREATE.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('SUGGESTIONS.API.ERROR_MESSAGE'));
  } finally {
    isCreating.value = false;
  }
};

const moveSuggestion = async ({ suggestionId, suggestionColumnId, position }) => {
  if (!canManage.value) return;
  try {
    await store.dispatch('suggestions/move', {
      id: suggestionId,
      suggestionColumnId,
      position,
    });
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('SUGGESTIONS.API.ERROR_MESSAGE'));
    loadBoard();
  }
};

const deleteSuggestion = async suggestion => {
  try {
    await store.dispatch('suggestions/delete', suggestion.id);
    useAlert(t('SUGGESTIONS.API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('SUGGESTIONS.API.ERROR_MESSAGE'));
  }
};

// Um campo gerenciavel por vez (responsavel, prioridade, categoria, tempo
// gasto) - o dialogo de detalhe manda so o que mudou.
const updateSuggestion = async patch => {
  try {
    await store.dispatch('suggestions/update', patch);
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('SUGGESTIONS.API.ERROR_MESSAGE'));
    loadBoard();
  }
};

const goToColumnSettings = () => {
  router.push({ name: 'suggestion_columns_list' });
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 min-w-0 p-4 gap-4 bg-n-surface-1">
    <header class="flex items-center justify-between flex-shrink-0">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('SUGGESTIONS.HEADER.TITLE') }}
        </h1>
        <p class="text-xs text-n-slate-11 mt-0.5">
          {{ t('SUGGESTIONS.HEADER.SUBTITLE') }}
        </p>
      </div>
      <div v-if="canManage" class="flex items-center gap-2">
        <NextButton
          faded
          slate
          size="sm"
          icon="i-lucide-settings"
          :label="t('SUGGESTIONS.HEADER.CONFIGURE_COLUMNS')"
          @click="goToColumnSettings"
        />
        <NextButton
          size="sm"
          icon="i-lucide-plus"
          :label="t('SUGGESTIONS.HEADER.ADD_BUTTON')"
          @click="openCreateDialog"
        />
      </div>
    </header>

    <div class="flex flex-wrap items-end gap-2 flex-shrink-0">
      <label class="flex flex-col gap-1 min-w-[140px]">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.FILTERS.PRIORITY') }}
        </span>
        <select v-model="filters.priorityId" class="mb-0">
          <option value="">{{ t('SUGGESTIONS.FILTERS.ALL') }}</option>
          <option
            v-for="priority in priorities"
            :key="priority.id"
            :value="String(priority.id)"
          >
            {{ priority.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-[140px]">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.FILTERS.CATEGORY') }}
        </span>
        <select v-model="filters.categoryId" class="mb-0">
          <option value="">{{ t('SUGGESTIONS.FILTERS.ALL') }}</option>
          <option
            v-for="category in categories"
            :key="category.id"
            :value="String(category.id)"
          >
            {{ category.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-[140px]">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.FILTERS.ASSIGNEE') }}
        </span>
        <select v-model="filters.assigneeId" class="mb-0">
          <option value="">{{ t('SUGGESTIONS.FILTERS.ALL') }}</option>
          <option
            v-for="admin in administrators"
            :key="admin.id"
            :value="String(admin.id)"
          >
            {{ admin.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.FILTERS.DATE_FROM') }}
        </span>
        <input v-model="filters.dateFrom" type="date" class="mb-0" />
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('SUGGESTIONS.FILTERS.DATE_TO') }}
        </span>
        <input v-model="filters.dateTo" type="date" class="mb-0" />
      </label>

      <NextButton
        v-if="hasActiveFilters"
        faded
        slate
        size="sm"
        icon="i-lucide-x"
        :label="t('SUGGESTIONS.FILTERS.CLEAR')"
        @click="clearFilters"
      />
    </div>

    <main class="flex-1 flex flex-col min-h-0 min-w-0">
      <div v-if="uiFlags.isFetching && !columns.length" class="flex items-center justify-center flex-1">
        <Spinner size="lg" />
      </div>
      <SuggestionBoard
        v-else
        :columns="columns"
        :suggestions="filteredSuggestions"
        :read-only="!canManage"
        @open-suggestion="openSuggestion"
        @move-suggestion="moveSuggestion"
      />
    </main>

    <SuggestionDetailDialog
      ref="detailDialog"
      :can-manage="canManage"
      :is-admin="isAdmin"
      @delete="deleteSuggestion"
      @update="updateSuggestion"
    />
    <SuggestionCreateDialog
      v-if="canManage"
      ref="createDialog"
      :is-loading="isCreating"
      @submit="createSuggestion"
    />
  </div>
</template>
