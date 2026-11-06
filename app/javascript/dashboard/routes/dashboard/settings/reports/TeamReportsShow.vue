<script setup>
import { useRoute } from 'vue-router';
import { useFunctionGetter } from 'dashboard/composables/store';

import WootReports from './components/WootReports.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';

const route = useRoute();
const team = useFunctionGetter('teams/getTeamById', route.params.id);
</script>

<template>
  <WootReports
    v-if="team.id"
    :key="team.id"
    type="team"
    getter-key="teams/getTeams"
    action-key="teams/get"
    :selected-item="team"
    :download-button-label="$t('TEAM_REPORTS.DOWNLOAD_TEAM_REPORTS')"
    :report-title="$t('TEAM_REPORTS.HEADER')"
    has-back-button
  />
  <PageLoader v-else />
</template>
