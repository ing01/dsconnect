<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import {
  hoursMinutesToSeconds,
  secondsToHoursMinutes,
} from 'dashboard/helper/ticketSlaHelper';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import TeamWorkingHours from './TeamWorkingHours.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

// As prioridades reais do Ticket, na ordem em que o produto as apresenta.
// Nenhuma lista paralela e nenhum prazo embutido: uma prioridade sem linha
// salva simplesmente não promete prazo.
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

const selectedTeamId = ref(null);
const isSaving = ref(false);
// O que está sendo editado na tabela, por prioridade. Já nasce completo porque
// a tabela renderiza antes da primeira leitura.
const emptyDraft = () =>
  Object.fromEntries(
    PRIORITIES.map(priority => [priority, { response: '', resolution: '' }])
  );
const draft = ref(emptyDraft());

const teams = computed(() => getters['teams/getTeams'].value);
const policies = computed(() =>
  selectedTeamId.value
    ? getters['ticketColumns/getSlaPolicies'].value(selectedTeamId.value)
    : []
);
const workingHours = computed(() =>
  selectedTeamId.value
    ? getters['ticketColumns/getWorkingHours'].value(selectedTeamId.value)
    : null
);

const policyFor = priority =>
  policies.value.find(policy => policy.priority === priority);

const resetDraft = () => {
  draft.value = Object.fromEntries(
    PRIORITIES.map(priority => {
      const policy = policyFor(priority);
      return [
        priority,
        {
          response: secondsToHoursMinutes(policy?.response_threshold),
          resolution: secondsToHoursMinutes(policy?.resolution_threshold),
        },
      ];
    })
  );
};

const load = async teamId => {
  if (!teamId) return;
  await Promise.all([
    store.dispatch('ticketColumns/fetchSlaPolicies', teamId),
    store.dispatch('ticketColumns/fetchWorkingHours', teamId),
  ]);
  resetDraft();
};

onBeforeMount(async () => {
  await store.dispatch('teams/get');
  selectedTeamId.value = teams.value[0]?.id ?? null;
});

watch(selectedTeamId, load);

// Vazio é uma resposta válida - significa "sem prazo". Só formato errado é erro.
const isInvalid = value =>
  !!value.trim() && hoursMinutesToSeconds(value) === null;

const hasInvalidRow = computed(() =>
  PRIORITIES.some(priority => {
    const row = draft.value[priority] || {};
    return isInvalid(row.response || '') || isInvalid(row.resolution || '');
  })
);

// Uma linha sem nenhum dos dois prazos não configura nada, então é apagada:
// é assim que se remove a promessa de prazo de uma prioridade.
const persistRow = async priority => {
  const row = draft.value[priority];
  const policy = policyFor(priority);
  const payload = {
    response_threshold: hoursMinutesToSeconds(row.response),
    resolution_threshold: hoursMinutesToSeconds(row.resolution),
  };
  const isEmpty = !payload.response_threshold && !payload.resolution_threshold;

  if (isEmpty) {
    if (policy) {
      await store.dispatch('ticketColumns/deleteSlaPolicy', {
        teamId: selectedTeamId.value,
        policyId: policy.id,
      });
    }
    return;
  }

  if (policy) {
    await store.dispatch('ticketColumns/updateSlaPolicy', {
      teamId: selectedTeamId.value,
      policyId: policy.id,
      ...payload,
    });
    return;
  }

  await store.dispatch('ticketColumns/createSlaPolicy', {
    teamId: selectedTeamId.value,
    priority,
    ...payload,
  });
};

const save = async () => {
  if (hasInvalidRow.value || isSaving.value) return;

  isSaving.value = true;
  try {
    // Em série: as ações recarregam a matriz, e em paralelo uma sobrescreveria
    // a leitura da outra.
    await PRIORITIES.reduce(
      (chain, priority) => chain.then(() => persistRow(priority)),
      Promise.resolve()
    );
    resetDraft();
    useAlert(t('TICKET.SETTINGS.PRIORITIES.SAVED'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};

// O expediente é da Mesa e vale para os três relógios. Desligado, os prazos
// correm em horas corridas.
const toggleBusinessHours = async event => {
  try {
    await store.dispatch('ticketColumns/updateWorkingHours', {
      teamId: selectedTeamId.value,
      working_hours_enabled: event.target.checked,
    });
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  }
};

const tableHeaders = computed(() => [
  t('TICKET.SETTINGS.PRIORITIES.TABLE.NAME'),
  t('TICKET.SETTINGS.PRIORITIES.TABLE.RESPONSE'),
  t('TICKET.SETTINGS.PRIORITIES.TABLE.RESOLUTION'),
]);
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.PRIORITIES.TITLE')"
        :description="t('TICKET.SETTINGS.PRIORITIES.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-5 min-w-0">
        <div class="flex flex-wrap items-end gap-4 min-w-0">
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('TICKET.SETTINGS.FORM.MESA.LABEL') }}
            </span>
            <select v-model="selectedTeamId" class="mb-0">
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ formatMesaName(team.name) }}
              </option>
            </select>
          </label>

          <label
            v-if="workingHours"
            class="flex items-center gap-2 pb-2 text-sm text-n-slate-11"
          >
            <input
              type="checkbox"
              class="m-0"
              :checked="workingHours.working_hours_enabled"
              @change="toggleBusinessHours"
            />
            {{ t('TICKET.SETTINGS.PRIORITIES.BUSINESS_HOURS') }}
          </label>
        </div>

        <div class="overflow-x-auto min-w-0">
          <BaseTable :headers="tableHeaders" :items="PRIORITIES">
            <template #row="{ items }">
              <BaseTableRow v-for="priority in items" :key="priority">
                <BaseTableCell>
                  {{ t(`TICKET.FORM.PRIORITY.${priority.toUpperCase()}`) }}
                </BaseTableCell>
                <BaseTableCell>
                  <input
                    v-model="draft[priority].response"
                    type="text"
                    :placeholder="
                      t('TICKET.SETTINGS.FORM.STAGE_SLA.PLACEHOLDER')
                    "
                    class="w-24 mb-0"
                    :class="{ error: isInvalid(draft[priority].response) }"
                  />
                </BaseTableCell>
                <BaseTableCell>
                  <input
                    v-model="draft[priority].resolution"
                    type="text"
                    :placeholder="
                      t('TICKET.SETTINGS.FORM.STAGE_SLA.PLACEHOLDER')
                    "
                    class="w-24 mb-0"
                    :class="{ error: isInvalid(draft[priority].resolution) }"
                  />
                </BaseTableCell>
              </BaseTableRow>
            </template>
          </BaseTable>
        </div>

        <p class="text-sm text-n-slate-11">
          {{ t('TICKET.SETTINGS.PRIORITIES.HINT') }}
        </p>

        <!-- O expediente vale para os três relógios, então mora junto dos
             prazos que ele governa. -->
        <div
          v-if="workingHours && workingHours.working_hours_enabled"
          class="pt-2 border-t border-n-weak"
        >
          <TeamWorkingHours
            :team-id="selectedTeamId"
            :working-hours="workingHours"
          />
        </div>

        <div class="flex justify-end">
          <Button
            :label="t('TICKET.SETTINGS.PRIORITIES.SAVE')"
            :disabled="hasInvalidRow || !selectedTeamId"
            :is-loading="isSaving"
            @click="save"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
