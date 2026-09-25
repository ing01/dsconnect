<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { secondsToHoursMinutes } from 'dashboard/helper/ticketSlaHelper';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import AddStage from './AddStage.vue';
import EditStage from './EditStage.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const selectedTeamId = ref(null);
const selectedStage = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const isReordering = ref(false);

const teams = computed(() => getters['teams/getTeams'].value);
const uiFlags = computed(() => getters['ticketColumns/getUIFlags'].value);
const selectedBoard = computed(() =>
  selectedTeamId.value
    ? getters['ticketColumns/getBoard'].value(selectedTeamId.value)
    : null
);
// The board endpoint already nests each Estagio's tickets, so the per-stage
// count comes for free - no extra request and no counter column to keep in sync.
const stages = computed(() => selectedBoard.value?.ticket_columns ?? []);

const ticketCount = stage => stage.tickets?.length ?? 0;

// O prazo do Estagio, em HH:MM. Sem prazo e uma resposta valida, e a tabela
// precisa dizer isso em vez de deixar a celula vazia.
const stageDeadline = stage =>
  secondsToHoursMinutes(stage.stage_threshold) ||
  t('TICKET.SETTINGS.TABLE.NO_SLA');

const tableHeaders = computed(() => [
  t('TICKET.SETTINGS.TABLE.NAME'),
  t('TICKET.SETTINGS.TABLE.MESA'),
  t('TICKET.SETTINGS.TABLE.KIND'),
  t('TICKET.SETTINGS.TABLE.STAGE_SLA'),
  t('TICKET.SETTINGS.TABLE.TICKETS'),
  t('TICKET.SETTINGS.TABLE.ACTIONS'),
]);

const kindLabel = stage =>
  t(`TICKET.SETTINGS.FORM.KIND.${(stage.kind || 'normal').toUpperCase()}`);

const isRequiredKind = stage => !!stage.kind && stage.kind !== 'normal';

const deleteMessage = computed(() => ` ${selectedStage.value.name}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};
const openEditPopup = stage => {
  selectedStage.value = stage;
  showEditPopup.value = true;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};
const openDeletePopup = stage => {
  selectedStage.value = stage;
  showDeleteConfirmationPopup.value = true;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = async () => {
  const stage = selectedStage.value;
  closeDeletePopup();
  try {
    await store.dispatch('ticketColumns/deleteColumn', {
      teamId: selectedTeamId.value,
      columnId: stage.id,
    });
    useAlert(t('TICKET.API.COLUMN_DELETE_SUCCESS'));
  } catch (error) {
    // The backend refuses to delete an Estagio that still holds tickets and says
    // how many - surface that rather than a generic failure.
    useAlert(
      parseAPIErrorResponse(error) || t('TICKET.API.COLUMN_DELETE_ERROR')
    );
  }
};

const moveStage = async (index, delta) => {
  const columnIds = stages.value.map(stage => stage.id);
  const target = index + delta;
  if (target < 0 || target >= columnIds.length) return;

  [columnIds[index], columnIds[target]] = [columnIds[target], columnIds[index]];

  isReordering.value = true;
  try {
    await store.dispatch('ticketColumns/reorderColumns', {
      teamId: selectedTeamId.value,
      columnIds,
    });
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.API.REORDER_ERROR'));
  } finally {
    isReordering.value = false;
  }
};

watch(selectedTeamId, teamId => {
  if (teamId) store.dispatch('ticketColumns/fetchBoard', teamId);
});

onBeforeMount(async () => {
  await store.dispatch('teams/get');
  selectedTeamId.value = teams.value[0]?.id ?? null;
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('TICKET.SETTINGS.LOADING')"
    :no-records-found="!teams.length"
    :no-records-message="$t('TICKET.SETTINGS.NO_MESA')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('TICKET.SETTINGS.STAGES.HEADER')"
        :description="$t('TICKET.SETTINGS.STAGES.DESCRIPTION')"
      >
        <template #actions>
          <div class="flex items-center gap-2">
            <select
              v-if="teams.length"
              v-model="selectedTeamId"
              class="h-8 rounded-lg border border-n-strong bg-transparent px-2 text-sm text-n-slate-12"
              :aria-label="$t('TICKET.SETTINGS.MESA_LABEL')"
            >
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ formatMesaName(team.name) }}
              </option>
            </select>
            <Button
              :label="$t('TICKET.SETTINGS.ADD_STAGE')"
              size="sm"
              :disabled="!selectedTeamId"
              @click="openAddPopup"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="stages"
        :no-data-message="$t('TICKET.SETTINGS.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="(stage, index) in items"
            :key="stage.id"
            :item="stage"
          >
            <template #default>
              <BaseTableCell>
                <span class="inline-flex items-center gap-1.5">
                  <span class="text-body-main text-n-slate-12">
                    {{ stage.name }}
                  </span>
                  <span
                    v-if="stage.hidden"
                    class="text-xxs font-medium text-n-slate-11 bg-n-slate-4 rounded-full px-1.5 py-0.5"
                  >
                    {{ $t('TICKET.SETTINGS.FORM.HIDDEN.BADGE') }}
                  </span>
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ formatMesaName(selectedBoard?.name) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span
                  class="text-body-main"
                  :class="
                    stage.kind && stage.kind !== 'normal'
                      ? 'text-n-teal-11 font-medium'
                      : 'text-n-slate-11'
                  "
                >
                  {{ kindLabel(stage) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ stageDeadline(stage) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ ticketCount(stage) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('TICKET.SETTINGS.MOVE_UP')"
                    icon="i-lucide-arrow-up"
                    slate
                    sm
                    :disabled="index === 0 || isReordering"
                    @click="moveStage(index, -1)"
                  />
                  <Button
                    v-tooltip.top="$t('TICKET.SETTINGS.MOVE_DOWN')"
                    icon="i-lucide-arrow-down"
                    slate
                    sm
                    :disabled="index === items.length - 1 || isReordering"
                    @click="moveStage(index, 1)"
                  />
                  <Button
                    v-tooltip.top="$t('TICKET.SETTINGS.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(stage)"
                  />
                  <Button
                    v-tooltip.top="
                      isRequiredKind(stage)
                        ? $t('TICKET.SETTINGS.FORM.KIND.HINT')
                        : ticketCount(stage)
                          ? $t('TICKET.SETTINGS.DELETE_BLOCKED_HINT')
                          : $t('TICKET.SETTINGS.DELETE')
                    "
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :disabled="ticketCount(stage) > 0 || isRequiredKind(stage)"
                    @click="openDeletePopup(stage)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>

      <!-- Categories live under the same Mesa selector as the Estagios: both
           lists belong to the Mesa chosen above. -->
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddStage
        :teams="teams"
        :team-id="selectedTeamId"
        :stage-count="stages.length"
        @close="hideAddPopup"
      />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditStage
        :stage="selectedStage"
        :teams="teams"
        :stage-count="stages.length"
        @close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('TICKET.COLUMN_DELETE.TITLE')"
      :message="$t('TICKET.COLUMN_DELETE.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('TICKET.COLUMN_DELETE.CONFIRM')"
      :reject-text="$t('TICKET.COLUMN_DELETE.CANCEL')"
    />
  </SettingsLayout>
</template>
