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

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { checkPermissions } = usePolicy();

const canManage = computed(() =>
  checkPermissions(['administrator', 'suggestion_manage'])
);

const columns = computed(() => store.getters['suggestionColumns/getColumns']);
const suggestions = computed(() => store.getters['suggestions/getSuggestions']);
const uiFlags = computed(() => store.getters['suggestions/getUIFlags']);

const detailDialog = ref(null);
const createDialog = ref(null);
const isCreating = ref(false);

const loadBoard = () => {
  store.dispatch('suggestionColumns/get');
  store.dispatch('suggestionPriorities/get');
  store.dispatch('suggestionCategories/get');
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

    <main class="flex-1 flex flex-col min-h-0 min-w-0">
      <div v-if="uiFlags.isFetching && !columns.length" class="flex items-center justify-center flex-1">
        <Spinner size="lg" />
      </div>
      <SuggestionBoard
        v-else
        :columns="columns"
        :suggestions="suggestions"
        :read-only="!canManage"
        @open-suggestion="openSuggestion"
        @move-suggestion="moveSuggestion"
      />
    </main>

    <SuggestionDetailDialog
      ref="detailDialog"
      :can-manage="canManage"
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
