<script setup>
import { onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';

import WootReports from './components/WootReports.vue';
import PageLoader from 'dashboard/components-next/spinner/PageLoader.vue';

const route = useRoute();
const store = useStore();
const label = useFunctionGetter('labels/getLabelById', route.params.id);

onMounted(() => store.dispatch('labels/get'));
</script>

<template>
  <WootReports
    v-if="label.id"
    :key="label.id"
    type="label"
    getter-key="labels/getLabels"
    action-key="labels/get"
    :selected-item="label"
    :download-button-label="$t('LABEL_REPORTS.DOWNLOAD_LABEL_REPORTS')"
    :report-title="$t('LABEL_REPORTS.HEADER')"
    has-back-button
  />
  <PageLoader v-else />
</template>
