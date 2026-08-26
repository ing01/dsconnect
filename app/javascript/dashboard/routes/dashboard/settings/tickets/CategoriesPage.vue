<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import TicketCategoriesSection from './TicketCategoriesSection.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

// Categories belong to a Mesa, so this page carries the same Mesa selector the
// Estagios page does.
const selectedTeamId = ref(null);
const teams = computed(() => getters['teams/getTeams'].value);
const uiFlags = computed(() => getters['ticketColumns/getUIFlags'].value);

onBeforeMount(async () => {
  await store.dispatch('teams/get');
  selectedTeamId.value = teams.value[0]?.id ?? null;
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('TICKET.SETTINGS.LOADING')"
    :no-records-found="!teams.length"
    :no-records-message="t('TICKET.SETTINGS.NO_MESA')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.CATEGORIES.TITLE')"
        :description="t('TICKET.SETTINGS.CATEGORIES.DESCRIPTION')"
      >
        <template #actions>
          <select
            v-if="teams.length"
            v-model="selectedTeamId"
            class="h-8 px-2 text-sm bg-transparent border rounded-lg border-n-strong text-n-slate-12"
            :aria-label="t('TICKET.SETTINGS.MESA_LABEL')"
          >
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ formatMesaName(team.name) }}
            </option>
          </select>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <TicketCategoriesSection :team-id="selectedTeamId" />
    </template>
  </SettingsLayout>
</template>
