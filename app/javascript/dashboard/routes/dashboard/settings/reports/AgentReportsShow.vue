<script setup>
import { onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';

import WootReports from './components/WootReports.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';

const route = useRoute();
const store = useStore();
const agent = useFunctionGetter('agents/getAgentById', route.params.id);

onMounted(() => store.dispatch('agents/get'));
</script>

<template>
  <WootReports
    v-if="agent.id"
    :key="agent.id"
    type="agent"
    getter-key="agents/getAgents"
    action-key="agents/get"
    :selected-item="agent"
    :download-button-label="$t('AGENT_REPORTS.DOWNLOAD_AGENT_REPORTS')"
    :report-title="$t('AGENT_REPORTS.HEADER')"
    has-back-button
  />
  <PageLoader v-else />
</template>
