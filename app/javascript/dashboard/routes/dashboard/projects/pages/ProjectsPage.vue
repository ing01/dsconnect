<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { formatMesaName } from 'dashboard/helper/mesaName';

import ProjectBoard from '../components/ProjectBoard.vue';
import ProjectCreateDialog from '../components/ProjectCreateDialog.vue';
import ProjectDetailModal from '../components/ProjectDetailModal.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const selectedTeamId = ref(null);
const searchQuery = ref('');
const showCompleted = ref(false);
const showCreateModal = ref(false);
const selectedProjectId = ref(null);

const teams = computed(() => store.getters['teams/getTeams'] || []);
const projects = computed(() => store.getters['projects/getProjects'] || []);
const uiFlags = computed(() => store.getters['projects/getUIFlags'] || {});

const activeProjectsCount = computed(() => projects.value.filter(p => p.stage !== 'finalizado').length);
const completedProjectsCount = computed(() => projects.value.filter(p => p.stage === 'finalizado').length);

const loadProjects = () => {
  store.dispatch('projects/get', {
    team_id: selectedTeamId.value || undefined,
    search: searchQuery.value || undefined,
    completed: showCompleted.value ? 'true' : undefined,
  });
};

onMounted(async () => {
  await store.dispatch('teams/get');
  if (teams.value.length && !selectedTeamId.value) {
    selectedTeamId.value = teams.value[0].id;
  }
  loadProjects();
});

watch([selectedTeamId, showCompleted], () => {
  loadProjects();
});

let searchTimeout = null;
watch(searchQuery, () => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    loadProjects();
  }, 300);
});

const onMoveProject = async ({ project, newStage }) => {
  try {
    await store.dispatch('projects/update', {
      id: project.id,
      stage: newStage,
    });
    useAlert(t('PROJECTS.DETAIL.STAGE_UPDATED'));
  } catch (error) {
    useAlert(error.message || t('PROJECTS.DETAIL.UPDATE_ERROR'));
    loadProjects();
  }
};

const openProjectDetail = project => {
  selectedProjectId.value = project.id;
};

const goToModulesSettings = () => {
  router.push({ name: 'project_modules_list' });
};

const goToTasksSettings = () => {
  router.push({ name: 'project_tasks_list' });
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 min-w-0 p-4 gap-4 bg-n-surface-1">
    <!-- Header -->
    <header class="flex flex-col gap-3 w-full min-w-0 flex-shrink-0">
      <div class="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ t('PROJECTS.HEADER.TITLE') }}
          </h1>
          <p class="text-xs text-n-slate-11 mt-0.5">
            {{ t('PROJECTS.HEADER.SUBTITLE') }}
          </p>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center gap-2">
          <NextButton
            faded
            slate
            size="sm"
            icon="i-lucide-layers"
            :label="t('PROJECTS.HEADER.MODULES_SHORTCUT')"
            @click="goToModulesSettings"
          />
          <NextButton
            faded
            slate
            size="sm"
            icon="i-lucide-check-square"
            :label="t('PROJECTS.HEADER.TASKS_SHORTCUT')"
            @click="goToTasksSettings"
          />
          <NextButton
            size="sm"
            icon="i-lucide-plus"
            :label="t('PROJECTS.HEADER.NEW_PROJECT')"
            @click="showCreateModal = true"
          />
        </div>
      </div>

      <!-- Controls Row: Team selector, Search, Active vs Completed switch -->
      <div class="flex items-center justify-between flex-wrap gap-3 pt-3 border-t border-n-weak">
        <div class="flex items-center gap-3 flex-wrap">
          <!-- Mesa Selector -->
          <div class="flex items-center gap-2">
            <span class="text-xs font-medium text-n-slate-11">
              {{ t('PROJECTS.FILTER.MESA') }}:
            </span>
            <select
              v-model="selectedTeamId"
              class="h-8 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 font-medium focus:border-n-brand focus:outline-none"
            >
              <option :value="null">{{ t('PROJECTS.FILTER.ALL_MESAS') }}</option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ formatMesaName(team.name) }}
              </option>
            </select>
          </div>

          <!-- Active / Completed toggle buttons -->
          <div class="flex items-center bg-n-slate-3 p-0.5 rounded-lg text-xs">
            <button
              type="button"
              class="px-3 py-1 rounded-md font-medium transition-colors"
              :class="
                !showCompleted
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="showCompleted = false"
            >
              {{ t('PROJECTS.FILTER.ACTIVE_PROJECTS') }} ({{ activeProjectsCount }})
            </button>
            <button
              type="button"
              class="px-3 py-1 rounded-md font-medium transition-colors"
              :class="
                showCompleted
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="showCompleted = true"
            >
              {{ t('PROJECTS.FILTER.COMPLETED_PROJECTS') }} ({{ completedProjectsCount }})
            </button>
          </div>
        </div>

        <!-- Search Input -->
        <div class="w-56">
          <NextInput
            v-model="searchQuery"
            size="sm"
            icon="i-lucide-search"
            :placeholder="t('PROJECTS.FILTER.SEARCH_PLACEHOLDER')"
          />
        </div>
      </div>
    </header>

    <!-- Main Kanban Area -->
    <main class="flex-1 flex flex-col min-h-0 min-w-0">
      <div v-if="uiFlags.isFetching && !projects.length" class="flex items-center justify-center flex-1">
        <Spinner size="lg" />
      </div>

      <div v-else-if="!projects.length" class="flex flex-col items-center justify-center flex-1 text-center p-8 bg-n-solid-1 rounded-xl border border-n-weak">
        <div class="w-16 h-16 rounded-full bg-n-slate-3 flex items-center justify-center mb-4">
          <Icon icon="i-lucide-kanban" class="size-8 text-n-slate-8" />
        </div>
        <h3 class="text-base font-semibold text-n-slate-12 mb-1">
          {{ showCompleted ? t('PROJECTS.EMPTY.NO_COMPLETED') : t('PROJECTS.EMPTY.NO_PROJECTS') }}
        </h3>
        <p class="text-xs text-n-slate-10 max-w-sm mb-5 leading-relaxed">
          {{ t('PROJECTS.EMPTY.HINT') }}
        </p>
        <NextButton
          v-if="!showCompleted"
          size="sm"
          icon="i-lucide-plus"
          :label="t('PROJECTS.HEADER.NEW_PROJECT')"
          @click="showCreateModal = true"
        />
      </div>

      <ProjectBoard
        v-else
        :projects="projects"
        :show-completed="showCompleted"
        @open-project="openProjectDetail"
        @move-project="onMoveProject"
      />
    </main>

    <!-- Create Project Modal -->
    <woot-modal
      v-if="showCreateModal"
      :show="showCreateModal"
      :on-close="() => (showCreateModal = false)"
    >
      <ProjectCreateDialog
        :initial-team-id="selectedTeamId"
        @close="showCreateModal = false"
        @created="loadProjects"
        @open-add-module="goToModulesSettings"
      />
    </woot-modal>

    <!-- Project Detail Modal -->
    <woot-modal
      v-if="selectedProjectId"
      :show="!!selectedProjectId"
      :on-close="() => (selectedProjectId = null)"
    >
      <ProjectDetailModal
        :project-id="selectedProjectId"
        @close="selectedProjectId = null"
        @updated="loadProjects"
      />
    </woot-modal>
  </div>
</template>
